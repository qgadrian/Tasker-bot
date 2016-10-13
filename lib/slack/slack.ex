defmodule Tasker.SlackBot do
  use Slack

  require IEx
  require Logger

   # commands
   @command_task "Task"
   @command_list_tasks "Tasks"
   @command_group "Group"
   @command_list_groups "Groups"
   # actions
   @action_create_task "new"
   @action_task_done "done"
   @action_create_group "new"

   @slack_bot_id "USLACKBOT"

  def handle_connect(slack) do
    IO.puts "Connected as #{slack.me.name}"
  end

  def handle_message(message = %{type: "message"}, slack) do
    Logger.debug "Handle message #{inspect(message)}"

    command = get_first_regexp_match(~r/<@#{slack.me.id}>:?\s(.+)/, message.text)

    Logger.debug "Requested command #{command}"

    cond do
      nil ->
        Logger.debug "Invalid command"

      Regex.match?(~r/#{@command_task} #{@action_create_task} (.+) ?(.+ )*/, command) ->
        matches =
          Regex.run(
          ~r/#{@command_task} #{@action_create_task} (?<task_name>\w+) ?((?<task_users><@.+>)|(?<task_group>\w+))*/,
          command, capture: ["task_name", "task_group", "task_users"])

        Logger.debug "Found the following matches #{inspect(matches)}"

        case matches do
          [task_name, "", ""] ->
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

      Regex.match?(~r/#{@command_list_tasks}/, command) ->
        active_tasks = get_print_tasks_msg()
        send_message("<@#{message.user}> active tasks:\n#{active_tasks}", message.channel, slack)

      Regex.match?(~r/#{@command_task} (\w+) #{@action_task_done}/, command) ->
        task_name = get_first_regexp_match(~r/#{@command_task} (\w+) #{@action_task_done}/, command)
        updated_cached_tasks = update_cached_tasks(task_name, "<@#{message.user}>")

        ConCache.put(:task_stuff_cache, :tasks, updated_cached_tasks)

        send_message("<@#{message.user}> task #{task_name} done", message.channel, slack)

      Regex.match?(~r/#{@command_group} #{@action_create_group} (?<group_name>\w+) ?(?<group_users>.+)*/, command) ->
        matches = Regex.run(~r/#{@command_group} #{@action_create_group} (?<group_name>\w+) ?(?<group_users>.+)*/, command, capture: :all_but_first)

        case matches do
          [group_name] ->
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

        Regex.match?(~r/#{@command_list_groups}/, command) ->
          groups = get_print_groups_msg()
          send_message("<@#{message.user}> groups:\n#{groups}", message.channel, slack)

      true ->
        Logger.debug "No matching"
    end
    {:ok}
  end

  # Any other message will be ignored
  def handle_message(_message, _slack) do
    # IO.puts "Other message type: #{inspect(message)}"
    {:ok}
  end

  def handle_info({:message, text, channel}, slack) do
    IO.puts "Sending your message, captain!"
    send_message(text, channel, slack)
    {:ok}
  end

  defp get_cached_tasks() do
    case ConCache.get(:task_stuff_cache, :tasks) do
      nil -> []
      active_tasks -> active_tasks
    end
  end

  # Private functions

  defp send_group_creation_success_message(group, message, slack) do
    user_mention_list =
      group.users
      |> Enum.map(fn(user_name) -> "#{user_name}" end)
      |> Enum.join(" ")

     send_message("<@#{message.user}> created a new group named #{group.name}. Members are: #{user_mention_list}", message.channel, slack)

     group
  end

  defp send_task_creation_success_message(task, message, slack) do
     send_message("<@#{message.user}> created a new task named #{task.name}", message.channel, slack)

     task
  end

  defp send_task_request_user_mentions(task, message, slack) do
    user_mention_list =
      task.users
      |> Enum.map(fn(user_name) -> "#{user_name}" end)
      |> Enum.join(" ")
    send_message("#{task.name} should be done by: #{user_mention_list}", message.channel, slack)

    task
  end

  defp update_cached_tasks(task_name, task_user) do
      Enum.map(get_cached_tasks(), fn(cached_task) ->
        case cached_task.name do
          task_name ->
            updated_users = Enum.filter(cached_task.users, fn(user) -> user != task_user end)
            case updated_users do
              [] -> nil
              updated_users -> %Task{name: cached_task.name, users: updated_users}
            end
          _ ->
            cached_task
        end
      end)
      |> Enum.reject(fn(cached_task) ->
        cached_task == nil
      end)
  end

  defp get_print_tasks_msg() do
    case get_cached_tasks() do
      [] -> "There are no active tasks"
      cached_tasks ->
        Enum.map(cached_tasks, fn(task) ->
          users_list =
            Enum.join(task.users, ", ")
          "*#{task.name}*\nRemaining users: #{users_list}\n\n"
        end)
    end
  end

  defp get_print_groups_msg() do
    case get_cached_groups() do
      [] -> "There are no groups created"
      cached_groups ->
        Enum.map(cached_groups, fn(group) ->
          users_list =
            Enum.join(group.users, ", ")
          "*#{group.name}*\nMembers: #{users_list}\n\n"
        end)
    end
  end

  defp get_cached_groups() do
    case ConCache.get(:task_stuff_cache, :groups) do
      nil -> []
      groups -> groups
    end
  end

  defp get_cached_group(group_name) do
    case ConCache.get(:task_stuff_cache, :groups) do
      nil -> []
      groups ->
        case Enum.reject(groups, fn(group)-> group.name != group_name end) do
          [] -> %Group{}
          groups -> List.first(groups)
        end
    end
  end

  defp add_task_to_cache(task_users, task_name) do
    task = %Task{name: task_name, users: task_users}

    case get_cached_tasks() do
     [] ->
       ConCache.put(:task_stuff_cache, :tasks, [task])
     cached_tasks ->
       ConCache.put(:task_stuff_cache, :tasks, cached_tasks ++ [task])
    end

    task
  end

  defp add_group_to_cache(group_users, group_name) do
    group = %Group{name: group_name, users: group_users}

    case get_cached_groups() do
     [] ->
       ConCache.put(:task_stuff_cache, :groups, [group])
     cached_groups ->
       ConCache.put(:task_stuff_cache, :groups, cached_groups ++ [group])
    end

    group
  end

  defp get_first_regexp_match(regexp, text, options \\ :all_but_first) do
    case Regex.run(regexp, text, capture: options) do
      nil -> ""
      matches -> List.first(matches)
    end
  end

end
