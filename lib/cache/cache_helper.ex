defmodule Tasker.CacheHelper do

  alias Tasker.{Task, Group}

  def get_cached_tasks() do
    case ConCache.get(:tasker_cache, :tasks) do
      nil -> []
      active_tasks -> active_tasks
    end
  end

  def get_cached_groups() do
    case ConCache.get(:tasker_cache, :groups) do
      nil -> []
      groups -> groups
    end
  end

  def get_cached_group(group_name) do
    case ConCache.get(:tasker_cache, :groups) do
      nil -> []
      groups ->
        case Enum.reject(groups, fn(group)-> group.name != group_name end) do
          [] -> %Group{}
          groups -> List.first(groups)
        end
    end
  end

  def add_tasks_to_cache(tasks), do: ConCache.put(:tasker_cache, :tasks, tasks)

  def add_groups_to_cache(groups), do: ConCache.put(:tasker_cache, :groups, groups)

  def add_task_to_cache(task_users, task_name) do
    task = %Task{name: task_name, users: task_users}

    case get_cached_tasks() do
     [] ->
       ConCache.put(:tasker_cache, :tasks, [task])
     cached_tasks ->
       ConCache.put(:tasker_cache, :tasks, cached_tasks ++ [task])
    end

    task
  end

  def add_group_to_cache(group_users, group_name) do
    group = %Group{name: group_name, users: group_users}

    case get_cached_groups() do
     [] ->
       ConCache.put(:tasker_cache, :groups, [group])
     cached_groups ->
       ConCache.put(:tasker_cache, :groups, cached_groups ++ [group])
    end

    group
  end

end
