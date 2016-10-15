defmodule Tasker.SlackBot do
  use Slack

  require IEx
  require Logger

  import Tasker.CacheHelper
  import Tasker.MessageHelper

  alias Tasker.{Task, Group}

   # commands
   @command_task "Task"
   @command_list_tasks "Tasks"
   @command_group "Group"
   @command_list_groups "Groups"
   # actions
   @action_create_task "new"
   @action_task_done "done"
   @action_create_group "new"
   @action_group_add_users "add"
   @action_group_remove_users "remove"

   # Slack bot id
   @slack_bot_id "USLACKBOT"

   # Regular expressions
   @regexp_create_task ~r/#{@command_task} #{@action_create_task} (?<task_name>\w+) ?((?<task_users><@.+>)|(?<task_group>\w+))*/
   @regexp_list_tasks ~r/#{@command_list_tasks}/
   @regexp_task_done ~r/#{@command_task} (\w+) #{@action_task_done}/
   @regexp_create_group ~r/#{@command_group} #{@action_create_group} (?<group_name>\w+) ?(?<group_users>.+)*/
   @regexp_group_list ~r/#{@command_list_groups}/
   @regexp_group_add_users ~r/#{@command_group} (?<group_name>\w+) #{@action_group_add_users} ?(?<new_users><@.+>)*/
   @regexp_group_remove_users ~r/#{@command_group} (?<group_name>\w+) #{@action_group_remove_users} ?(?<users_to_remove><@.+>)*/

  def handle_connect(slack) do
    IO.puts "Connected as #{slack.me.name}"
  end

  def handle_message(message = %{type: "message"}, slack) do
    Logger.debug "Handle message #{inspect(message)}"

    command = get_first_regexp_match(~r/<@#{slack.me.id}>:?\s(.+)/, message.text)

    Logger.debug "Requested command #{command}"

    cond do
      Regex.match?(@regexp_create_task, command) ->
        matches =
          Regex.run(@regexp_create_task, command, capture: ["task_name", "task_group", "task_users"])

        Logger.debug "Found the following matches #{inspect(matches)}"

        case matches do
          [_, "", ""] ->
            send_message("<@#{message.user}> you must tell me which group or users will have to do the task", message.channel, slack)
          [task_name, "", "all"] ->
            slack.users
            |> Enum.reject(fn({user_name, user_params}) -> user_name == @slack_bot_id || user_params.is_bot end)
            |> Enum.map(fn({user_name,_}) -> "<@#{user_name}>" end)
            |> add_task_to_cache(task_name)
            |> send_task_creation_success_message(message, slack)
            |> send_task_request_user_mentions(message, slack)

          [task_name, "", task_users] ->
            task_users
            |> String.split(" ")
            |> Enum.reject(fn(user_name) -> user_name == "<@#{@slack_bot_id}>" end)
            |> add_task_to_cache(task_name)
            |> send_task_creation_success_message(message, slack)
            |> send_task_request_user_mentions(message, slack)

          [task_name, task_group, ""] ->
            get_cached_group(task_group).users
            |> Enum.reject(fn(user_name) -> user_name == "<@#{@slack_bot_id}>" end)
            |> add_task_to_cache(task_name)
            |> send_task_creation_success_message(message, slack)
            |> send_task_request_user_mentions(message, slack)
        end

      Regex.match?(@regexp_list_tasks, command) ->
        active_tasks = get_print_tasks_msg()
        send_message("Active tasks:\n#{active_tasks}", message.channel, slack)

      Regex.match?(@regexp_task_done, command) ->
        task_name = get_first_regexp_match(@regexp_task_done, command)

        task_name
        |> update_cached_tasks("<@#{message.user}>")
        |> add_groups_to_cache()

        send_message("<@#{message.user}> task #{task_name} done", message.channel, slack)

      Regex.match?(@regexp_create_group, command) ->
        matches = Regex.run(@regexp_create_group, command, capture: :all_but_first)

        case matches do
          [_, ""] ->
            send_message("<@#{message.user}> you must tell me the users that will be members of the group", message.channel, slack)
          [group_name, "all"] ->
            slack.users
            |> Enum.reject(fn({user_name, user_params}) -> user_name == @slack_bot_id || user_params.is_bot end)
            |> Enum.map(fn({user_name,_}) -> "<@#{user_name}>" end)
            |> add_group_to_cache(group_name)
            |> send_group_creation_success_message(message, slack)

          [group_name, group_users] ->
            group_users
            |> String.split(" ")
            |> Enum.reject(fn(user_name) -> user_name == "<@#{@slack_bot_id}>" end)
            |> add_group_to_cache(group_name)
            |> send_group_creation_success_message(message, slack)
        end

        Regex.match?(@regexp_group_add_users, command) ->
          matches = Regex.run(@regexp_group_add_users, command, capture: :all_but_first)
          case matches do
            [_, ""] ->
              send_message("<@#{message.user}> you forgot tell me the new members of the group", message.channel, slack)
            [group_name, new_users_string] ->
              new_users = new_users_string |> String.split(" ")

              new_users
              |> Enum.reject(fn(new_user_name) -> new_user_name == @slack_bot_id end)
              |> updated_group_users(group_name, :add)
              |> add_groups_to_cache()

              send_group_users_add_success_message(group_name, new_users, message, slack)
          end

        Regex.match?(@regexp_group_remove_users, command) ->
          matches = Regex.run(@regexp_group_remove_users, command, capture: :all_but_first)
          case matches do
            [_, ""] ->
              send_message("<@#{message.user}> you forgot tell me the members the will removed from the group", message.channel, slack)
            [group_name, user_to_remove_string] ->
              users_to_remove = user_to_remove_string |> String.split(" ")

              users_to_remove
              |> Enum.reject(fn(user_to_remove) -> user_to_remove == @slack_bot_id end)
              |> updated_group_users(group_name, :remove)
              |> add_groups_to_cache()

              send_group_users_remove_success_message(group_name, users_to_remove, message, slack)
          end

        Regex.match?(@regexp_group_list, command) ->
          groups = get_print_groups_msg()
          send_message("Available groups:\n#{groups}", message.channel, slack)

      true ->
        Logger.debug "No matching"
    end
    {:ok}
  end

  def handle_message(_message, _slack) do
    # Logger.debug "Other message type: #{inspect(message)}"
    {:ok}
  end

  def handle_info(_whatever, _slack) do
    # Logger.debug "Info received #{inspect(_whatever)}"
    {:ok}
  end

  # Private functions

  defp update_cached_tasks(task_name, task_user) do
      Enum.map(get_cached_tasks(), fn(cached_task) ->
        cond do
          cached_task.name == task_name ->
            updated_users = Enum.filter(cached_task.users, fn(user) -> user != task_user end)
            case updated_users do
              [] -> nil
              updated_users -> %Task{name: cached_task.name, users: updated_users}
            end
          true ->
            cached_task
        end
      end)
      |> Enum.reject(fn(cached_task) ->
        cached_task == nil
      end)
  end


  defp updated_group_users(new_users, group_name, :add) do
      Enum.map(get_cached_groups(), fn(cached_group) ->
        cond do
          cached_group.name == group_name ->
            %Group{name: group_name, users: cached_group.users ++ new_users}
          true ->
            cached_group
        end
      end)
  end

  defp updated_group_users(new_users, group_name, :remove) do
      Enum.map(get_cached_groups(), fn(cached_group) ->
        cond do
          cached_group.name == group_name ->
            %Group{name: group_name, users: substract(cached_group.users, new_users) }
          true ->
            cached_group
        end
      end)
  end

  defp substract(source_list, list_to_substract) do
     Enum.reject(source_list, fn(source_element) ->
       Enum.any?(list_to_substract, fn(element_to_substract) ->
         source_element == element_to_substract
       end)
     end)
  end

  defp get_first_regexp_match(regexp, text, options \\ :all_but_first) do
    case Regex.run(regexp, text, capture: options) do
      nil -> ""
      matches -> List.first(matches)
    end
  end

end
