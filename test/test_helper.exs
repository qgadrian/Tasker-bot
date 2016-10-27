ExUnit.start()

defmodule MultipleResultsFound do
  defexception message: "Found multiple results with a same name"
end

defmodule NoResultFound do
   defexception message: "No result found"
end

defmodule Tasker.TestHelper do

  defmacro __using__(_) do
    quote do
      @task_name_task_1 "task_1"
      @group_name_group_1 "group_1"
      @task_creation_timestamp "23"

      @some_users_slack_ids "<@user1> <@user2> <@user3> <@user4>"
      @some_users_names_list ["user1", "user2", "user3", "user4"]
    end
  end

  def get_slack_with_added_users(users_names) do
    users_names_with_added =
      users_names
      |> Map.new(fn(user_name) -> {user_name, %{id: user_name, is_bot: false}} end)
      |> Map.merge(slack_rtm().users)

    Map.merge(Tasker.TestHelper.slack_rtm(), %{users: users_names_with_added})
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
          "user1" => %{id: "user1", is_bot: false},
          "user2" => %{id: "user2", is_bot: false},
          "user3" => %{id: "user3", is_bot: false},
          "user4" => %{id: "user4", is_bot: false},
          "bot1" => %{id: "bot1", is_bot: true},
          "USLACKBOT" => %{id: "USLACKBOT", is_bot: false}
        },
      ims: %{id: "imu1"}
    }
  end

  def slack_rtm_users(include_bots \\ false) do
    case include_bots do
      true ->
        slack_rtm().users
      false ->
        slack_rtm().users
        |> Enum.reject(fn({user_name, user_params}) -> user_name == "USLACKBOT" || user_params.is_bot end)
        |> Enum.into(%{})
    end
  end

  def get_cached_group(group_name) do
    case ConCache.get(:tasker_cache, :groups) do
       nil -> raise NoResultFound
       cached_groups ->
         found_cached_groups = cached_groups |> Enum.filter(fn(cached_group) -> cached_group.name == group_name end)

         case length(found_cached_groups) do
            1 -> List.first(found_cached_groups)
            0 -> raise NoResultFound
            _ -> raise MultipleResultsFound
         end
    end
  end

  def get_cached_task(task_name) do
    case ConCache.get(:tasker_cache, :tasks) do
      nil -> raise NoResultFound
      cache_tasks ->
        found_cached_tasks = cache_tasks |> Enum.filter(fn(cached_task) -> cached_task.name == task_name end)

        case length(found_cached_tasks) do
           1 -> List.first(found_cached_tasks)
           0 -> raise NoResultFound
           _ -> raise MultipleResultsFound
        end
    end
  end
end
