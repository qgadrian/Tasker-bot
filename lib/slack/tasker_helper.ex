defmodule Tasker.TaskerHelper do

  import Tasker.CacheHelper

  # Slack bot id
  @slack_bot_id "USLACKBOT"

  # Tasks
    def create_task_for_users(slack_users, task_name, timestamp) when is_map(slack_users) do
      case Enum.any?(get_cached_tasks(), fn(cached_task) -> cached_task.name == task_name end) do
        true -> :error
        false ->
          slack_users
          |> Enum.reject(fn({user_name, user_params}) -> user_name == @slack_bot_id || user_params.is_bot end)
          |> Enum.map(fn({user_name,_}) -> user_name end)
          |> add_task_to_cache(task_name, timestamp)
      end
    end

    def create_task_for_users(users_string, task_name, timestamp, slack) do
      users_string
      |> get_slack_users(slack)
      |> create_task_for_users(task_name, timestamp)
    end

    def create_task_for_group(group_name, task_name, timestamp) do
      case Enum.any?(get_cached_tasks(), fn(cached_task) -> cached_task.name == task_name end) do
        true -> :error
        false ->
          get_cached_group(group_name).users
          |> add_task_to_cache(task_name, timestamp)
      end
    end

    def do_task(slack_users, task_name) when is_map(slack_users) do
      task_name
      |> updated_task_users(slack_users, :remove)
      |> add_tasks_to_cache()
    end

    def do_task({:users, users_string}, task_name, slack) do
      users_string
      |> get_slack_users(slack)
      |> do_task(task_name)
    end

    def do_task({:group, group_name}, task_name, slack) do
      slack_users = Map.take(slack.users, get_cached_group(group_name).users)

      task_name
      |> updated_task_users(slack_users, :remove)
      |> add_tasks_to_cache()
    end

    def rename_task(task_name, task_new_name) do
      {task_name, task_new_name}
      |> updated_tasks(:rename)
      |> add_tasks_to_cache()
    end

    def remove_task(task_name) do
      task_name
      |> updated_tasks(:remove)
      |> add_tasks_to_cache()

      task_name
    end

  # Groups
    def create_users_group(users_map, group_name) when is_map(users_map) do
      case Enum.any?(get_cached_groups(), fn(cached_group) -> cached_group.name == group_name end) do
        true -> :error
        false ->
          group =
            users_map
            |> Enum.reject(fn({user_name, user_params}) -> user_name == @slack_bot_id || user_params.is_bot end)
            |> Enum.map(fn({user_name,_}) -> user_name end)
            |> add_group_to_cache(group_name)

          {:ok, group}
      end
    end

    def create_users_group(users_string, group_name, slack) do
      users_string
      |> get_slack_users(slack)
      |> create_users_group(group_name)
    end

    def add_users_to_group(users_string, group_name, slack) do
      users_string
      |> get_slack_users(slack)
      |> Enum.reject(fn({user_name, user_params}) -> user_name == @slack_bot_id || user_params.is_bot end)
      |> Enum.into(%{})
      |> updated_group_users(group_name, :add)
      |> add_groups_to_cache()
    end

    def remove_users_from_group(users_string, group_name, slack) do
      users_string
      |> get_slack_users(slack)
      |> updated_group_users(group_name, :remove)
      |> add_groups_to_cache()
    end

    def remove_group(group_name) do
      group_name
      |> updated_groups(:remove)
      |> add_groups_to_cache()

      group_name
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

  defp updated_task_users(task_name, users_to_remove, :remove) do
      Enum.map(get_cached_tasks(), fn(cached_task) ->
        cond do
          cached_task.name == task_name ->
            updated_users = Enum.reject(cached_task.users, fn(user) -> user in Map.keys(users_to_remove) end)

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

  defp updated_group_users(slack_users, group_name, :add) do
    user_ids = Map.keys(slack_users)

    Enum.map(get_cached_groups(), fn(cached_group) ->
      cond do
        cached_group.name == group_name ->
          new_group_users = cached_group.users ++ user_ids |> Enum.uniq()
          Map.put(cached_group, :users, new_group_users)
        true ->
          cached_group
      end
    end)
  end

  defp updated_group_users(slack_users, group_name, :remove) do
    user_ids = Map.keys(slack_users)

    Enum.map(get_cached_groups(), fn(cached_group) ->
      cond do
        cached_group.name == group_name ->
          Map.put(cached_group, :users, cached_group.users -- user_ids)
        true ->
          cached_group
      end
    end)
  end

  def get_slack_users(users_string, slack) do
    slack_user_ids =
      users_string
      |> String.split(~r{( )+})
      |> Enum.map(fn(user) -> List.first Regex.run(~r{<@(?<user_id>(\w*))>}, user, capture: ["user_id"]) end)
      |> Enum.filter(fn(user_string) -> Map.has_key?(slack.users, user_string) end)

    Map.take(slack.users, slack_user_ids)
  end

end
