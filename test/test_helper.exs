ExUnit.start()

defmodule MultipleResultsFound do
  defexception message: "Found multiple results with a same name"
end

defmodule NoResultFound do
   defexception message: "No result found"
end

defmodule Tasker.TestHelper do
  def slack_rtm_users_id_list() do
     ["<@u1>", "<@u2>", "<@u3>", "<@u4>"]
  end

  def slack_rtm() do
    %{
      me: %{id: "me"},
      team: %{name: "team"},
      bots: [%{id: "b1"}],
      channels: [%{id: "c1"}],
      groups: [%{id: "g1"}],
      users:
        %{
          "u1" => %{id: "u1", is_bot: false},
          "u2" => %{id: "u2", is_bot: false},
          "u3" => %{id: "u3", is_bot: false},
          "u4" => %{id: "u4", is_bot: false}
        },
      slack_users:
        %{
          "<@u1>" => %{id: "<@u1>", is_bot: false},
          "<@u2>" => %{id: "<@u2>", is_bot: false},
          "<@u3>" => %{id: "<@u3>", is_bot: false},
          "<@u4>" => %{id: "<@u4>", is_bot: false}
        },
      ims: %{id: "imu1"}
    }
  end

  def get_cached_group(group_name) do
    found_cached_groups = Enum.filter(ConCache.get(:tasker_cache, :groups), fn(cached_group) ->
      cached_group.name == group_name
    end)

    case length(found_cached_groups) do
       1 -> List.first(found_cached_groups)
       0 -> raise NoResultFound
       _ -> raise MultipleResultsFound
    end
  end

  def get_cached_task(task_name) do
    found_cached_tasks = Enum.filter(ConCache.get(:tasker_cache, :tasks), fn(cached_task) ->
      cached_task.name == task_name
    end)

    case length(found_cached_tasks) do
       1 -> List.first(found_cached_tasks)
       0 -> raise NoResultFound
       _ -> raise MultipleResultsFound
    end
  end
end
