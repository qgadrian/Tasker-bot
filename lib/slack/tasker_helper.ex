defmodule Tasker.TaskerHelper do

  import Tasker.CacheHelper

  # Slack bot id
  @slack_bot_id "USLACKBOT"

  # Tasks
    def create_task_for_users(slack_users, task_name, timestamp) when is_map(slack_users) do
      case Enum.any?(get_cached_tasks(), fn(cached_task) -> cached_task.name == task_name end) do
        true -> :error
        false ->
          task =
            slack_users
            |> Enum.reject(fn({user_name, user_params}) -> user_name == @slack_bot_id || user_params.is_bot end)
            |> Enum.map(fn({user_name,_}) -> "<@#{user_name}>" end)
            |> add_task_to_cache(task_name, timestamp)

          {:ok, task}
      end
    end

    def create_task_for_users(users, task_name, timestamp) do
      case Enum.any?(get_cached_tasks(), fn(cached_task) -> cached_task.name == task_name end) do
        true -> :error
        false ->
          task =
            users
            |> get_slack_users_ids()
            |> Enum.reject(fn(user_name) -> user_name == "<@#{@slack_bot_id}>" end)
            |> add_task_to_cache(task_name, timestamp)

          {:ok, task}
      end
    end

    def create_task_for_group(group_name, task_name, timestamp) do
      case Enum.any?(get_cached_tasks(), fn(cached_task) -> cached_task.name == task_name end) do
        true -> :error
        false ->
          task =
            get_cached_group(group_name).users
            |> Enum.reject(fn(user_name) -> user_name == "<@#{@slack_bot_id}>" end)
            |> add_task_to_cache(task_name, timestamp)

          {:ok, task}
      end
    end

    def do_task(task_name, users_string, :users) do
      users = get_slack_users_ids(users_string)

      task_name
      |> updated_task_users(users, :remove)
      |> add_tasks_to_cache()
    end

    def do_task(task_name, group_name, :group) do
      task_name
      |> updated_task_users(get_cached_group(group_name).users, :remove)
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
            |> Enum.map(fn({user_name,_}) -> "<@#{user_name}>" end)
            |> add_group_to_cache(group_name)

          {:ok, group}
      end
    end

    def create_users_group(users_string, group_name) do
      case Enum.any?(get_cached_groups(), fn(cached_group) -> cached_group.name == group_name end) do
        true -> :error
        false ->
          group =
            users_string
            |> get_slack_users_ids()
            |> Enum.reject(fn(user_name) -> user_name == "<@#{@slack_bot_id}>" end)
            |> add_group_to_cache(group_name)

          {:ok, group}
      end
    end

    def add_users_to_group(user_names_to_add, group_name) do
      user_ids_to_add = get_slack_users_ids(user_names_to_add)

      user_ids_to_add
      |> Enum.reject(fn(user_name_to_add) -> user_name_to_add == @slack_bot_id end)
      |> updated_group_users(group_name, :add)
      |> add_groups_to_cache()

      user_ids_to_add
    end

    def remove_users_from_group(users_to_remove_string, group_name) do
      users_to_remove = get_slack_users_ids(users_to_remove_string)

      users_to_remove
      |> Enum.reject(fn(user_to_remove) -> user_to_remove == @slack_bot_id end)
      |> updated_group_users(group_name, :remove)
      |> add_groups_to_cache()

      users_to_remove
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

  defp updated_task_users(task_name, user_to_remove, :remove) when not is_list(user_to_remove) do
    updated_task_users(task_name, [user_to_remove], :remove)
  end

  defp updated_task_users(task_name, users_to_remove, :remove) when is_list(users_to_remove) do
      Enum.map(get_cached_tasks(), fn(cached_task) ->
        cond do
          cached_task.name == task_name ->
            updated_users = Enum.reject(cached_task.users, fn(user) -> user in users_to_remove end)

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
          new_group_users = cached_group.users ++ new_users |> Enum.uniq()

          Map.put(cached_group, :users, new_group_users)
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

  defp get_slack_users_ids(users) do
    users
    |> String.split(~r{( )+})
    |> Enum.map(fn(user) -> List.first Regex.run(~r{<@(\w*)>}, user, capture: :all_but_first) end)
  end

end
