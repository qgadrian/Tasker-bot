defmodule Tasker.SlackBot do
  use Slack

  import Tasker.MessageHelper
  import Tasker.TaskerHelper

  require Logger

   # commands
   @command_task "(?i)Task"
   @command_list_tasks "(?i)Tasks"
   @command_group "(?i)Group"
   @command_list_groups "(?i)Groups"
   @command_help "(?i)Help"

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

   # Slack mentions
   @slack_user_mentions_regex "(?<users>(<[@].+>))"
   @slack_channel_mention_regex "(<#(?<channel>\\w+)\\|\\w+>)"

   # Regular expressions
   @regexp_create_task ~r{#{@command_task} (#{@action_create}|#{@action_new}) #{@regex_task_name} (#{@slack_user_mentions_regex}|(?<task_group>\w+))}
   @regexp_remove_task ~r{#{@command_task} (#{@action_remove}|#{@action_delete}) ?#{@regex_task_name}}
   @regexp_rename_task ~r{#{@command_task} #{@regex_task_name} #{@action_rename_to} (?<task_new_name>\w+)}
   @regexp_list_tasks ~r{^#{@command_list_tasks}$}
   @regexp_task_users_done ~r{#{@command_task} #{@regex_task_name} ?(#{@slack_user_mentions_regex}|(?<task_group>\w*)) #{@action_task_done}}
   @regexp_create_group ~r{#{@command_group} (#{@action_create}|#{@action_new}) #{@regex_group_name} ?#{@slack_user_mentions_regex}}
   @regexp_remove_group ~r{#{@command_group} (#{@action_remove}|#{@action_delete}) ?#{@regex_group_name}}
   @regexp_group_list ~r{^#{@command_list_groups}$}
   @regexp_group_add_users ~r{#{@command_group} #{@regex_group_name} #{@action_group_add_users} ?#{@slack_user_mentions_regex}}
   @regexp_group_remove_users ~r{#{@command_group} #{@regex_group_name} (#{@action_remove}|#{@action_delete}) ?#{@slack_user_mentions_regex}}
   @regexp_notify_task ~r{#{@command_task} #{@action_notify} #{@regex_task_name} ?(on #{@slack_channel_mention_regex})* on (?<cron_sentence>[\* |\w+ ]*)}
   @regexp_remove_notify_task ~r{#{@command_task} #{@action_notify} (global|#{@regex_task_name}) (#{@action_remove}|#{@action_delete})}

   # Help regexps
   @regexp_help_task ~r{#{@command_help} #{@command_task}}
   @regexp_help_group ~r{#{@command_help} #{@command_group}}

  def handle_connect(slack, state) do
    IO.puts "Connected as #{slack.me.name}"
    {:ok, state}
  end

  def handle_event(message = %{type: "message"}, slack, state) do
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
            case create_task_for_users(slack.users, task_name, message.ts) do
              {:ok, task} ->
                send_task_creation_success_message(task, message, slack)
              :error ->
                send_task_name_already_in_used(message, slack)
            end

          [task_name, task_users, ""] ->
            case create_task_for_users(task_users, task_name, message.ts, slack) do
              {:ok, task} ->
                send_task_creation_success_message(task, message, slack)
              :error ->
               send_task_name_already_in_used(message, slack)
            end

          [task_name, "", task_group] ->
            case create_task_for_group(task_group, task_name, message.ts) do
              {:ok, task} ->
                send_task_creation_success_message(task, message, slack)
              :error ->
                send_task_name_already_in_used(message, slack)
            end
        end

      Regex.match?(@regexp_remove_task, command) ->
        matches = Regex.run(@regexp_remove_task, command, capture: ["task_name"])

        case matches do
          [""] ->
            send_message("<@#{message.user}> I don't know which task to delete!", message.channel, slack)
          [task_name] ->
            remove_task(task_name)
            |> send_task_remove_success_message(message, slack)
        end

      Regex.match?(@regexp_rename_task, command) ->
        matches = Regex.run(@regexp_rename_task, command, capture: ["task_name", "task_new_name"])

        case matches do
          [task_name, task_new_name] ->
            rename_task(task_name, task_new_name)
            send_message("<@#{message.user}> renamed #{task_name} to #{task_new_name}", message.channel, slack)
        end

      Regex.match?(@regexp_list_tasks, command) ->
        Logger.debug "List tasks command"
        send_task_list_message(message)

      Regex.match?(@regexp_task_users_done, command) ->
        matches = Regex.run(@regexp_task_users_done, command, capture: ["task_name", "users", "task_group"])

        case matches do
          [task_name, "", ""] ->
            do_task({:users, "<@#{message.user}>"}, task_name, slack)
            send_message("<@#{message.user}> task #{task_name} done", message.channel, slack)

          [task_name, task_users, ""] ->
            do_task({:users, task_users}, task_name, slack)
            send_message("<@#{message.user}> task #{task_name} done", message.channel, slack)

          [task_name, "", group_name] ->
            do_task({:group, group_name}, task_name, slack)
            send_message("<@#{message.user}> task #{task_name} done", message.channel, slack)
        end

      Regex.match?(@regexp_create_group, command) ->
        matches = Regex.run(@regexp_create_group, command, capture: ["group_name", "users"])

        case matches do
          [_, ""] ->
            send_message("<@#{message.user}> you must tell me the users that will be members of the group", message.channel, slack)
          [group_name, "all"] ->
            case create_users_group(slack.users, group_name) do
              {:ok, group} ->
                send_group_creation_success_message(group, message, slack)
              :error ->
                send_group_name_already_in_used(message, slack)
            end

          [group_name, group_users] ->
            case create_users_group(group_users, group_name, slack) do
              {:ok, group} ->
                send_group_creation_success_message(group, message, slack)
              :error ->
                send_group_name_already_in_used(message, slack)
            end
        end

        Regex.match?(@regexp_remove_group, command) ->
          matches = Regex.run(@regexp_remove_group, command, capture: ["group_name"])

          case matches do
            [""] ->
              send_message("<@#{message.user}> tell which group you want to delete, please.", message.channel, slack)
            [group_name] ->
              remove_group(group_name)
              |> send_group_remove_success_message(message, slack)
          end

        Regex.match?(@regexp_group_add_users, command) ->
          matches = Regex.run(@regexp_group_add_users, command, capture: ["group_name", "users"])

          case matches do
            [_, ""] ->
              send_message("<@#{message.user}> you forgot tell me the new members of the group", message.channel, slack)
            [group_name, new_group_users] ->
              add_users_to_group(new_group_users, group_name, slack)
              |> send_group_users_add_success_message(group_name, message, slack)
          end

        Regex.match?(@regexp_group_remove_users, command) ->
          matches = Regex.run(@regexp_group_remove_users, command, capture: ["group_name", "users"])

          case matches do
            [_, ""] ->
              send_message("<@#{message.user}> you forgot tell me the members the will removed from the group", message.channel, slack)
            [group_name, users_string_to_remove] ->
              remove_users_from_group(users_string_to_remove, group_name, slack)
              |> send_group_users_remove_success_message(group_name, message, slack)
          end

        Regex.match?(@regexp_group_list, command) ->
          send_group_list_message(message)

        Regex.match?(@regexp_notify_task, command) ->
          matches = Regex.run(@regexp_notify_task, command, capture: ["task_name", "channel", "cron_sentence"])

          case matches do
            ["all", "", cron_sentence] ->
              create_notification_job(:all_tasks, [:all_tasks, :im, slack], cron_sentence)
              send_message("Ok <@#{message.user}>! I will notify about all tasks by im's", message.channel, slack)

            ["all", channel, cron_sentence] ->
              create_notification_job(:all_tasks, [:all_tasks, channel, slack], cron_sentence)
              send_message("Ok <@#{message.user}>! I will notify about all tasks on <##{channel}>", message.channel, slack)

            [task_name, "", cron_sentence] ->
              create_notification_job(:"#{task_name}", [task_name, :im, slack], cron_sentence)
              send_message("Roger that <@#{message.user}>! I will notify about *#{task_name}* by im's", message.channel, slack)

            [task_name, channel, cron_sentence] ->
              create_notification_job(:"#{task_name}", [task_name, channel, slack], cron_sentence)
              send_message("Ok <@#{message.user}>! I will notify about *#{task_name}* on <##{channel}>", message.channel, slack)
          end

        Regex.match?(@regexp_help_task, command) -> send_task_commands_help(message)
        Regex.match?(@regexp_help_group, command) -> send_group_commands_help(message)

      true ->
        Logger.debug "Not maching found for: #{command}"
        send_message("<@#{message.user}> Sorry, what?", message.channel, slack)
    end

    {:ok, state}
  end

  def handle_event(_, _, state), do: {:ok, state}

  def handle_info({:message, text, channel}, _, state) do
    Logger.debug "Info: #{inspect({:message, text, channel})}"
    {:ok, state}
  end

  def handle_info(_, _, state), do: {:ok, state}

# Private functions
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

end
