defmodule Tasker.SlackBot do
  use Slack

  require IEx
  require Logger

   # commands
   @command_task "Task"
   @command_list_tasks "Tasks"
   # actions
   @action_create_task "new"
   @action_task_done "done"

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
        matches = Regex.run(~r/#{@command_task} #{@action_create_task} (?<task_name>\w+) ?(?<task_users>.+)*/, command, capture: :all_but_first)

        Logger.debug "Found the following matches #{inspect(matches)}"

        case matches do
          [task_name] ->
            send_message("<@#{message.user}> you must tell me which group or users will have to do the task", message.channel, slack)
          [task_name, task_users] ->
            add_task_to_cache(task_name, String.split(task_users, " "))
            send_message("<@#{message.user}> created a new task named #{task_name}", message.channel, slack)
        end

      Regex.match?(~r/#{@command_list_tasks}/, command) ->
        active_tasks = get_print_tasks_msg()
        send_message("<@#{message.user}> active tasks:\n#{active_tasks}", message.channel, slack)

      Regex.match?(~r/#{@command_task} (\w+) #{@action_task_done}/, command) ->
        task_name = get_first_regexp_match(~r/#{@command_task} (\w+) #{@action_task_done}/, command)
        updated_cached_tasks = update_cached_tasks(task_name, "<@#{message.user}>")

        ConCache.put(:task_stuff_cache, :tasks, updated_cached_tasks)

        send_message("<@#{message.user}> task #{task_name} done", message.channel, slack)

      true ->
        Logger.debug "No matching"
    end
    {:ok}
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

  defp add_task_to_cache(task_name, task_users) do
    task = %Task{name: task_name, users: task_users}

    case get_cached_tasks() do
     [] ->
       ConCache.put(:task_stuff_cache, :tasks, [task])
     cached_tasks ->
       ConCache.put(:task_stuff_cache, :tasks, cached_tasks ++ [task])
    end

    task_name
  end

  defp get_first_regexp_match(regexp, text, options \\ :all_but_first) do
    case Regex.run(regexp, text, capture: options) do
      nil -> ""
      matches -> List.first(matches)
    end
  end

end
