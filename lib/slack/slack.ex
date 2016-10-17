defmodule Tasker.SlackBot do
  use Slack

  require IEx
  require Logger

  import Tasker.CacheHelper
  import Tasker.MessageHelper

  alias Tasker.{Task, Group}

   # commands
   @command_task "(?i)Task"
   @command_list_tasks "(?i)Tasks"
   @command_group "(?i)Group"
   @command_list_groups "(?i)Groups"

   # actions
   @action_create "create"
   @action_new "new"
   @action_remove "remove"
   @action_delete "delete"
   @action_task_done "done"
   @action_group_add_users "add"
   @action_rename_to "rename to"
   @action_notify "notify"

   # Other regex
   @regex_task_name "(?<task_name>\\w+)"
   @regex_group_name "(?<group_name>\\w+)"

   # Slack bot id
   @slack_bot_id "USLACKBOT"

   # Slack mentions
   @slack_user_mentions_regex "(?<users>(<[@].+>))"
   @slack_channel_mention_regex "(<[#](?<channel>\\w+)\\|\\w+>)"

   # Regular expressions
   @regexp_create_task ~r{#{@command_task} (#{@action_create}|#{@action_new}) #{@regex_task_name} ?(#{@slack_user_mentions_regex}|(?<task_group>\w+))}
   @regexp_remove_task ~r{#{@command_task} (#{@action_remove}|#{@action_delete}) ?#{@regex_task_name}}
   @regexp_rename_task ~r{#{@command_task} #{@regex_task_name} #{@action_rename_to} (?<task_new_name>\w+)}
   @regexp_list_tasks ~r{^#{@command_list_tasks}$}
   @regexp_task_users_done ~r{#{@command_task} #{@regex_task_name} ?(#{@slack_user_mentions_regex}|(?<task_group>\w*)) #{@action_task_done}}
   @regexp_create_group ~r{#{@command_group} (#{@action_create}|#{@action_new}) #{@regex_group_name} ?#{@slack_user_mentions_regex}}
   @regexp_remove_group ~r{#{@command_group} (#{@action_remove}|#{@action_delete}) ?#{@regex_group_name}}
   @regexp_group_list ~r{^#{@command_list_groups}$}
   @regexp_group_add_users ~r{#{@command_group} #{@regex_group_name} #{@action_group_add_users} ?#{@slack_user_mentions_regex}}
   @regexp_group_remove_users ~r{#{@command_group} #{@regex_group_name} (#{@action_remove}|#{@action_delete}) ?#{@slack_user_mentions_regex}}
   @regexp_notify_task ~r{#{@command_task} #{@action_notify} #{@regex_task_name} on ?#{@slack_channel_mention_regex}* (?<cron_sentence>.+)}
   @regexp_remove_notify_task ~r{#{@command_task} #{@action_notify} (global|#{@regex_task_name}) (#{@action_remove}|#{@action_delete})}

  def handle_connect(slack) do
    IO.puts "Connected as #{slack.me.name}"
  end

  def handle_message(message = %{type: "message"}, slack) do
    Logger.debug "Handling message: #{inspect(message)}"

    command = get_message_command(message, slack)

    Logger.debug "Parsing command: #{command}"

    cond do
      Regex.match?(@regexp_create_task, command) ->
        matches = Regex.run(@regexp_create_task, command, capture: ["task_name", "users", "task_group"])

        case matches do
          [_, "", ""] ->
            send_message("<@#{message.user}> you must tell me which group or users will have to do the task", message.channel, slack)
          [task_name, "", "all"] ->
            slack.users
            |> Enum.reject(fn({user_name, user_params}) -> user_name == @slack_bot_id || user_params.is_bot end)
            |> Enum.map(fn({user_name,_}) -> "<@#{user_name}>" end)
            |> add_task_to_cache(task_name, message.ts)
            |> send_task_creation_success_message(message, slack)

          [task_name, task_users, ""] ->
            task_users
            |> get_slack_users_ids()
            |> Enum.reject(fn(user_name) -> user_name == "<@#{@slack_bot_id}>" end)
            |> add_task_to_cache(task_name, message.ts)
            |> send_task_creation_success_message(message, slack)

          [task_name, "", task_group] ->
            get_cached_group(task_group).users
            |> Enum.reject(fn(user_name) -> user_name == "<@#{@slack_bot_id}>" end)
            |> add_task_to_cache(task_name, message.ts)
            |> send_task_creation_success_message(message, slack)
        end

      Regex.match?(@regexp_remove_task, command) ->
        matches = Regex.run(@regexp_remove_task, command, capture: ["task_name"])

        case matches do
          [""] ->
            send_message("<@#{message.user}> I don't know which task to delete!", message.channel, slack)
          [task_name] ->
            task_name
            |> updated_tasks(:remove)
            |> add_tasks_to_cache()

            send_task_remove_success_message(task_name, message, slack)
        end

      Regex.match?(@regexp_rename_task, command) ->
        matches = Regex.run(@regexp_rename_task, command, capture: ["task_name", "task_new_name"])

        case matches do
          [task_name, task_new_name] ->
            {task_name, task_new_name}
            |> updated_tasks(:rename)
            |> add_tasks_to_cache()

            send_message("<@#{message.user}> renamed #{task_name} to #{task_new_name}", message.channel, slack)
        end

      Regex.match?(@regexp_list_tasks, command) ->
        Logger.debug "List tasks command"
        send_task_list_message(message)

      Regex.match?(@regexp_task_users_done, command) ->
        matches = Regex.run(@regexp_task_users_done, command, capture: ["task_name", "users", "task_group"])

        case matches do
          [task_name, "", ""] ->
            task_name
            |> updated_task_users("<@#{message.user}>", :remove)
            |> add_tasks_to_cache()

            send_message("<@#{message.user}> task #{task_name} done", message.channel, slack)
          [task_name, task_users, ""] ->
            users = get_slack_users_ids(task_users)

            task_name
            |> updated_task_users(users, :remove)
            |> add_tasks_to_cache()

            send_message("<@#{message.user}> task #{task_name} done", message.channel, slack)
          [task_name, "", group] ->
            task_name
            |> updated_task_users(get_cached_group(group).users, :remove)
            |> add_tasks_to_cache()

            send_message("<@#{message.user}> task #{task_name} done", message.channel, slack)

        end

      Regex.match?(@regexp_create_group, command) ->
        matches = Regex.run(@regexp_create_group, command, capture: ["group_name", "users"])

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
            |> get_slack_users_ids()
            |> Enum.reject(fn(user_name) -> user_name == "<@#{@slack_bot_id}>" end)
            |> add_group_to_cache(group_name)
            |> send_group_creation_success_message(message, slack)
        end

        Regex.match?(@regexp_remove_group, command) ->
          matches = Regex.run(@regexp_remove_group, command, capture: ["group_name"])

          case matches do
            [""] ->
              send_message("<@#{message.user}> tell which group you want to delete, please.", message.channel, slack)
            [group_name] ->
              group_name
              |> updated_groups(:remove)
              |> add_groups_to_cache()

              send_group_remove_success_message(group_name, message, slack)
          end

        Regex.match?(@regexp_group_add_users, command) ->
          matches = Regex.run(@regexp_group_add_users, command, capture: ["group_name", "users"])

          case matches do
            [_, ""] ->
              send_message("<@#{message.user}> you forgot tell me the new members of the group", message.channel, slack)
            [group_name, new_group_users] ->
              new_users = get_slack_users_ids(new_group_users)

              new_users
              |> Enum.reject(fn(new_user_name) -> new_user_name == @slack_bot_id end)
              |> updated_group_users(group_name, :add)
              |> add_groups_to_cache()

              send_group_users_add_success_message(group_name, new_users, message, slack)
          end

        Regex.match?(@regexp_group_remove_users, command) ->
          matches = Regex.run(@regexp_group_remove_users, command, capture: ["group_name", "users"])

          case matches do
            [_, ""] ->
              send_message("<@#{message.user}> you forgot tell me the members the will removed from the group", message.channel, slack)
            [group_name, group_users_to_remove] ->
              users_to_remove = get_slack_users_ids(group_users_to_remove)

              users_to_remove
              |> Enum.reject(fn(user_to_remove) -> user_to_remove == @slack_bot_id end)
              |> updated_group_users(group_name, :remove)
              |> add_groups_to_cache()

              send_group_users_remove_success_message(group_name, users_to_remove, message, slack)
          end

        Regex.match?(@regexp_group_list, command) ->
          send_group_list_message(message)

        Regex.match?(@regexp_notify_task, command) ->
          matches = Regex.run(@regexp_notify_task, command, capture: ["task_name", "channel", "cron_sentence"])

          case matches do
            [task_name, "", cron_sentence] ->
              create_notification_job(:all_tasks_notification, [:im, slack], cron_sentence)
              send_message("Roger that <@#{message.user}>! I will notify about *#{task_name}* by im's", message.channel, slack)

            [task_name, channel, cron_sentence] ->
              create_notification_job(:"#{task_name}", [task_name, channel, slack], cron_sentence)
              send_message("Ok <@#{message.user}>! I will notify about *#{task_name}* on <##{channel}>", message.channel, slack)
          end

      true ->
        Logger.debug "Not maching found for: #{command}"
        # send_message("<@#{message.user}> Sorry, what?", message.channel, slack)
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

  defp updated_tasks(task_name, :remove) do
    Enum.reject(get_cached_tasks(), fn(cached_task) -> cached_task.name == task_name end)
  end

  defp updated_tasks({task_name, task_new_name}, :rename) do
    Enum.map(get_cached_tasks(), fn(cached_task) ->
      cond do
        cached_task.name == task_name -> Map.put(cached_task, :name, task_new_name)
        true -> cached_task
      end
    end)
  end

  def updated_task_users(task_name, task_user, :remove) when not is_list(task_user) do
    updated_task_users(task_name, [task_user], :remove)
  end

  def updated_task_users(task_name, task_users, :remove) when is_list(task_users) do
      Enum.map(get_cached_tasks(), fn(cached_task) ->
        cond do
          cached_task.name == task_name ->
            updated_users = Enum.reject(cached_task.users, fn(user) -> user in task_users end)

            case updated_users do
              [] ->
                Quantum.delete_job(:"#{cached_task.name}")
                nil
              updated_users -> Map.put(cached_task, :users, updated_users)
            end

          true -> cached_task
        end
      end)
      |> Enum.reject(fn(cached_task) -> cached_task == nil end)
  end

  defp updated_groups(group_name, :remove) do
    Enum.reject(get_cached_groups(), fn(cached_group) -> cached_group.name == group_name end)
  end

  defp updated_group_users(new_users, group_name, :add) do
    Enum.map(get_cached_groups(), fn(cached_group) ->
      cond do
        cached_group.name == group_name ->
          Map.put(cached_group, :users, cached_group.users ++ new_users)
        true ->
          cached_group
      end
    end)
  end

  defp updated_group_users(users_to_remove, group_name, :remove) do
      Enum.map(get_cached_groups(), fn(cached_group) ->
        cond do
          cached_group.name == group_name ->
            Map.put(cached_group, :users, cached_group.users -- users_to_remove)
          true ->
            cached_group
        end
      end)
  end

  defp get_first_regexp_match(regexp, text, options \\ :all_but_first) do
    case Regex.run(regexp, text, capture: options) do
      nil -> ""
      matches -> List.first(matches)
    end
  end

  defp get_message_command(message, slack) do
    case Map.has_key?(slack.ims, message.channel) do
      true -> get_first_regexp_match(~r{(.+)}, message.text)
      false -> get_first_regexp_match(~r{<@#{slack.me.id}>:?\s(.+)}, message.text)
    end
  end

  defp create_notification_job(atom, args, cron_sentence) do
    sanitized_cron =
      Regex.replace(~r{( )+}, cron_sentence, " ")
      |> String.trim(" ")

    job = %Quantum.Job {
      name: atom,
      schedule: sanitized_cron,
      task: {Tasker.NotificationHelper, :notify_task_to_remaining_users},
      args: args
    }

    case Quantum.find_job(atom) do
      nil ->
        Quantum.add_job(atom, job)
      _ ->
        Quantum.delete_job(atom)
        Quantum.add_job(atom, job)
    end
  end

  defp get_slack_users_ids(users) do
    users
    |> String.split(~r{( )+})
    |> Enum.map(fn(user) -> List.first Regex.run(~r{<@(\w*)>}, user, capture: :all_but_first) end)
  end

end
