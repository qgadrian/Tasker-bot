defmodule Tasker.MessageHelper do
  use Slack

  import Tasker.CacheHelper

  # Atachment colors
  @info_color "#439FE0"
  @purple_color "#9C27B0"
  @indigo_color "#3F51B5"

  @slack_token Application.get_env(:tasker, Tasker.SlackBot)[:token]

  def send_task_list_message(message) do
    attachments =
      get_cached_tasks_attachments()
      |> JSX.encode!

    Slack.Web.Chat.post_message(message.channel, "These are the current tasks waiting to the remaining users to complete them:",
                            %{as_user: true, token: @slack_token, attachments: [attachments]})
  end

  def send_group_list_message(message) do
    attachments =
      get_cached_groups_attachments()
      |> JSX.encode!

    Slack.Web.Chat.post_message(message.channel, "Groups created until now:",
                            %{as_user: true, token: @slack_token, attachments: [attachments]})
  end

  def send_group_creation_success_message(group, message, slack) do
    user_mention_list = get_multiple_users_string_list(group.users)
     send_message("<@#{message.user}> created a new group named #{group.name}. Members are: #{user_mention_list}", message.channel, slack)

     group
  end

  def send_task_creation_success_message(task, message, slack) do
     send_message("<@#{message.user}> created a new task named #{task.name}", message.channel, slack)
     send_task_request_user_mentions(task, message, slack)
  end

  def send_task_remove_success_message(task_name, message, slack) do
     send_message("<@#{message.user}> removed task #{task_name}", message.channel, slack)
  end

  def send_group_remove_success_message(group_name, message, slack) do
     send_message("<@#{message.user}> removed group #{group_name}", message.channel, slack)
  end

  def send_task_request_user_mentions(task, message, slack) do
    user_mention_list = get_multiple_users_string_list(task.users)
    send_message("#{task.name} should be done by: #{user_mention_list}", message.channel, slack)
  end

  def send_group_users_add_success_message(group_name, new_users, message, slack) do
    case new_users do
      [single_user] -> send_message("<@#{single_user}> was added to #{group_name}", message.channel, slack)
      [_, _] ->
        multiple_users_string_list = get_multiple_users_string_list(new_users)
        send_message("#{multiple_users_string_list} were added to #{group_name}", message.channel, slack)
    end
  end

  def send_group_users_remove_success_message(group_name, users_to_remove, message, slack) do
    case users_to_remove do
      [single_user] -> send_message("<@#{single_user}> was removed from #{group_name}", message.channel, slack)
      [_, _] ->
        multiple_users_string_list = get_multiple_users_string_list(users_to_remove)
        send_message("#{multiple_users_string_list} were removed from #{group_name}", message.channel, slack)
    end
  end

  def send_task_name_already_in_used(message, slack) do
    send_message("<@#{message.user}> that task name it's already in use", message.channel, slack)
  end

  def get_multiple_users_string_list(users, acc \\ "") do
     case {users, acc} do
       {[single_user], ""} -> "<@#{single_user}>"
       {[last_user], acc} -> "#{acc} and <@#{last_user}>"
       {[user | rest], ""} -> get_multiple_users_string_list(rest, "<@#{user}>")
       {[user | rest], acc} -> get_multiple_users_string_list(rest, "#{acc}, <@#{user}>")
     end
  end

  def get_cached_tasks_attachments() do
    case get_cached_tasks() do
      [] -> [%{
          "color": "good",
          "author_name": "There are no task to be done!"
      }]
      cached_tasks ->
        Enum.map(cached_tasks, fn(cached_task) ->
          users_list =
            Enum.map(cached_task.users, fn(user_name) -> "<@#{user_name}>" end)
            |> Enum.join(", ")

          %{
              "color": "danger",
              "title": "#{cached_task.name}",
              "text": "Remaining: #{users_list}",
              "footer": "Created",
              "ts": "#{cached_task.creation_timestamp}"
          }
        end)
    end
  end

  def get_cached_groups_attachments() do
    case get_cached_groups() do
      [] -> [%{
          "color": "danger",
          "author_name": "There are no groups created"
      }]
      cached_groups ->
        Enum.map(cached_groups, fn(cached_group) ->
          users_list = get_multiple_users_string_list(cached_group.users)

          %{
              "color": "danger",
              "title": "#{cached_group.name}",
              "text": "#{users_list}"
          }
        end)
    end
  end

  # Help messages

  def send_task_commands_help(message, slack) do
    attachments = [
      %{
          "color": "good",
          "title": "Create new task",
          "text": "Task new TASK_NAME @user1 @user2"
      },
      %{
          "color": "danger",
          "title": "Remove a task",
          "text": "Task remove TASK_NAME"
      },
      %{
          "color": "warning",
          "title": "Rename a task",
          "text": "Task TASK_NAME rename to NEW_TASK_NAME"
      },
      %{
          "color": @indigo_color,
          "title": "List all tasks",
          "text": "Tasks"
      },
      %{
          "color": @info_color,
          "title": "Mark a task as done by me",
          "text": "Task TASK_NAME done"
      },
      %{
          "color": @info_color,
          "title": "Mark a task as done by others users",
          "text": "Task TASK_NAME @user1 @user2 done"
      },
      %{
          "color": @info_color,
          "title": "Mark a task as done by an entire group",
          "text": "Task TASK_NAME GROUP_NAME done"
      },
      %{
          "color": @purple_color,
          "title": "Notify all remaining tasks on channel",
          "text": "Task notify all on #CHANNEL_NAME * * * * *"
      },
      %{
          "color": @purple_color,
          "title": "Notify remaining task on channel",
          "text": "Task notify TASK_NAME on #CHANNEL_NAME * * * * *"
      },
      %{
          "color": @purple_color,
          "title": "Notify remaining task to all remaining users by im's",
          "text": "Task notify TASK_NAME on * * * * *"
      },
    ]
    |> JSX.encode!

    Slack.Web.Chat.post_message(message.channel, "These are the commands available for tasks:",
                            %{as_user: true, token: @slack_token, attachments: [attachments]})
  end

  def send_group_commands_help(message, slack) do
    attachments = [
      %{
          "color": "good",
          "title": "Create new group",
          "text": "Group new GROUP_NAME @user1 @user2"
      },
      %{
          "color": "danger",
          "title": "Remove a group",
          "text": "Group remove GROUP_NAME"
      },
      %{
          "color": @info_color,
          "title": "Add users to a group",
          "text": "Group GROUP_NAME add @user3 @user4"
      },
      %{
          "color": "danger",
          "title": "Remove users from a group",
          "text": "Group GROUP_NAME remove @user1 @user2"
      },
      %{
          "color": @indigo_color,
          "title": "List all groups",
          "text": "Groups"
      }
    ]
    |> JSX.encode!

    Slack.Web.Chat.post_message(message.channel, "These are the commands available for user groups:",
                            %{as_user: true, token: @slack_token, attachments: [attachments]})
  end

end
