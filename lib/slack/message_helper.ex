defmodule Tasker.MessageHelper do
  use Slack

  import Tasker.CacheHelper

  def send_group_creation_success_message(group, message, slack) do
    user_mention_list =
      group.users
      |> Enum.map(fn(user_name) -> "#{user_name}" end)
      |> Enum.join(" ")

     send_message("<@#{message.user}> created a new group named #{group.name}. Members are: #{user_mention_list}", message.channel, slack)

     group
  end

  def send_task_creation_success_message(task, message, slack) do
     send_message("<@#{message.user}> created a new task named #{task.name}", message.channel, slack)

     task
  end

  def send_task_request_user_mentions(task, message, slack) do
    user_mention_list =
      task.users
      |> Enum.map(fn(user_name) -> "#{user_name}" end)
      |> Enum.join(" ")
    send_message("#{task.name} should be done by: #{user_mention_list}", message.channel, slack)

    task
  end

  def send_group_users_add_success_message(group_name, new_users, message, slack) do
    case new_users do
      [single_user] -> send_message("#{single_user} was added to #{group_name}", message.channel, slack)
      [_, _] ->
        multiple_users_string_list = get_multiple_users_string_list(new_users)
        send_message("#{multiple_users_string_list} were added to #{group_name}", message.channel, slack)
    end
  end

  def send_group_users_remove_success_message(group_name, users_to_remove, message, slack) do
    case users_to_remove do
      [single_user] -> send_message("#{single_user} was removed from #{group_name}", message.channel, slack)
      [_, _] ->
        multiple_users_string_list = get_multiple_users_string_list(users_to_remove)
        send_message("#{multiple_users_string_list} were removed from #{group_name}", message.channel, slack)
    end
  end

  def get_multiple_users_string_list(users, acc \\ "") do
     case {users, acc} do
       {[single_user], ""} -> "#{single_user}"
       {[last_user], acc} -> "#{acc} and #{last_user}"
       {[user | rest], ""} -> get_multiple_users_string_list(rest, "#{user}")
       {[user | rest], acc} -> get_multiple_users_string_list(rest, "#{acc}, #{user}")
     end
  end

  def get_print_tasks_msg() do
    case get_cached_tasks() do
      [] -> "There are no active tasks"
      cached_tasks ->
        Enum.map(cached_tasks, fn(task) ->
          users_list = Enum.join(task.users, ", ")
          "*#{task.name}*\nRemaining users: #{users_list}\n\n"
        end)
    end
  end

  def get_print_groups_msg() do
    case get_cached_groups() do
      [] -> "There are no groups created"
      cached_groups ->
        Enum.map(cached_groups, fn(group) ->
          users_list = get_multiple_users_string_list(group.users)
          "*#{group.name}*\nMembers: #{users_list}\n\n"
        end)
    end
  end

end
