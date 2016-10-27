defmodule TaskerTest do
  use ExUnit.Case
  use Tasker.TestHelper

  doctest Tasker

  alias Tasker.{TaskerHelper, TestHelper}

  setup do
    Supervisor.terminate_child(Tasker.Supervisor, ConCache)
    Supervisor.restart_child(Tasker.Supervisor, ConCache)
    :ok
  end

# Task tests
  test "create new task with some users" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp, Tasker.TestHelper.slack_rtm())

    cached_caches = ConCache.get(:tasker_cache, :tasks)

    assert Enum.any?(cached_caches, fn(cached_task) -> cached_task.name == @task_name_task_1 end)
  end

  test "create new task with all users" do
    TaskerHelper.create_task_for_users(Tasker.TestHelper.slack_rtm().users, @task_name_task_1, @task_creation_timestamp)

    cached_caches = ConCache.get(:tasker_cache, :tasks)

    assert Enum.all?(cached_caches, fn(cached_task) ->
      Enum.all?(cached_task.users, fn(cached_user_name) ->
        Enum.any?(TestHelper.slack_rtm().users, fn({user_name, _}) ->
          cached_user_name == user_name
        end)
      end)
    end)
  end

  test "create new task only with bots" do
    TaskerHelper.create_task_for_users("<@bot1>", @task_name_task_1, @task_creation_timestamp, Tasker.TestHelper.slack_rtm())

    assert_raise(NoResultFound, fn -> TestHelper.get_cached_task(@task_name_task_1) end)
  end

  test "create new task with a name that already exists using user names" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp, Tasker.TestHelper.slack_rtm())

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.name == @task_name_task_1
    assert cached_task.users == @some_users_names_list

    assert :error == TaskerHelper.create_task_for_users("<@user5> <@user6>", @task_name_task_1, @task_creation_timestamp, Tasker.TestHelper.slack_rtm())
  end

  test "create new task with a name that already exists using all users" do
    TaskerHelper.create_task_for_users(Tasker.TestHelper.slack_rtm().users, @task_name_task_1, @task_creation_timestamp)

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.name == @task_name_task_1
    assert cached_task.users == @some_users_names_list

    assert :error == TaskerHelper.create_task_for_users(Tasker.TestHelper.slack_rtm().users, @task_name_task_1, @task_creation_timestamp)
  end

  test "create new task with a name that already exists using a group" do
    TaskerHelper.create_task_for_users(Tasker.TestHelper.slack_rtm().users, @task_name_task_1, @task_creation_timestamp)

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.name == @task_name_task_1
    assert cached_task.users == @some_users_names_list

    TaskerHelper.create_users_group("<@user3>", @group_name_group_1, Tasker.TestHelper.slack_rtm())

    assert :error == TaskerHelper.create_task_for_group(@group_name_group_1, @task_name_task_1, @task_creation_timestamp)
  end

  test "mark a task as done by the current user" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp, Tasker.TestHelper.slack_rtm())

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.users == @some_users_names_list

    TaskerHelper.do_task({:users, "<@user1>"}, @task_name_task_1, Tasker.TestHelper.slack_rtm())

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.users == ["user2", "user3", "user4"]
  end

  test "mark a task as done by some users" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp, Tasker.TestHelper.slack_rtm())

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.users == @some_users_names_list

    TaskerHelper.do_task({:users, "<@user1> <@user2>"}, @task_name_task_1, Tasker.TestHelper.slack_rtm())

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.users == ["user3", "user4"]
  end

  test "mark a task as done by an entire group" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp, Tasker.TestHelper.slack_rtm())
    TaskerHelper.create_users_group("<@user1> <@user2>", @group_name_group_1, Tasker.TestHelper.slack_rtm())

    TaskerHelper.do_task({:group, @group_name_group_1}, @task_name_task_1, Tasker.TestHelper.slack_rtm())

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.users == ["user3", "user4"]
  end

  test "a task is removed when its mark as done by all of its users" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp, Tasker.TestHelper.slack_rtm())

    TestHelper.get_cached_task(@task_name_task_1)

    TaskerHelper.do_task({:users, @some_users_slack_ids}, @task_name_task_1, Tasker.TestHelper.slack_rtm())

    assert_raise(NoResultFound, fn -> TestHelper.get_cached_task(@task_name_task_1) end)
  end

  test "remove a task" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp, Tasker.TestHelper.slack_rtm())

    TestHelper.get_cached_task(@task_name_task_1)

    TaskerHelper.remove_task(@task_name_task_1)

    assert_raise(NoResultFound, fn -> TestHelper.get_cached_task(@task_name_task_1) end)
  end

  test "rename a task" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp, Tasker.TestHelper.slack_rtm())

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.name == @task_name_task_1

    TaskerHelper.rename_task(@task_name_task_1, "a_task_name")

    assert_raise(NoResultFound, fn -> TestHelper.get_cached_task(@task_name_task_1) end)
    assert TestHelper.get_cached_task("a_task_name").name == "a_task_name"
  end

# Group tests
  test "create new user group with all users" do
    TaskerHelper.create_users_group(Tasker.TestHelper.slack_rtm().users, @group_name_group_1)

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == Map.keys(TestHelper.slack_rtm_users())
  end

  test "create new user group with some users" do
    TaskerHelper.create_users_group(@some_users_slack_ids, @group_name_group_1, Tasker.TestHelper.slack_rtm())

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == @some_users_names_list
  end

  test "create new user group with a name that already exists" do
    TaskerHelper.create_users_group(Tasker.TestHelper.slack_rtm().users, @group_name_group_1)

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == Map.keys(TestHelper.slack_rtm_users())

    assert :error == TaskerHelper.create_users_group("<@user23>", @group_name_group_1, Tasker.TestHelper.slack_rtm())
  end

  test "add a user that is already added to a group" do
    TaskerHelper.create_users_group(@some_users_slack_ids, @group_name_group_1, Tasker.TestHelper.slack_rtm())

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == @some_users_names_list

    TaskerHelper.add_users_to_group("<@user3>", @group_name_group_1, Tasker.TestHelper.slack_rtm())

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.users == (@some_users_names_list)
  end

  test "add an inexistent user to a group" do
    TaskerHelper.create_users_group(@some_users_slack_ids, @group_name_group_1, Tasker.TestHelper.slack_rtm())

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == @some_users_names_list

    TaskerHelper.add_users_to_group("<@user_not_existent>", @group_name_group_1, Tasker.TestHelper.slack_rtm())

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.users == @some_users_names_list
  end

  test "add a user to a group" do
    TaskerHelper.create_users_group(@some_users_slack_ids, @group_name_group_1, Tasker.TestHelper.slack_rtm())

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == @some_users_names_list

    slack_with_new_user = TestHelper.get_slack_with_added_users(["user5"])

    TaskerHelper.add_users_to_group("<@user5>", @group_name_group_1, slack_with_new_user)

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.users == (@some_users_names_list ++ ["user5"])
  end

  test "remove a user from a group" do
    TaskerHelper.create_users_group(@some_users_slack_ids, @group_name_group_1, Tasker.TestHelper.slack_rtm())

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == @some_users_names_list

    TaskerHelper.remove_users_from_group("<@user1>", @group_name_group_1, Tasker.TestHelper.slack_rtm())

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.users == ["user2", "user3", "user4"]
  end

  test "remove various users from a group" do
    TaskerHelper.create_users_group(@some_users_slack_ids, @group_name_group_1, Tasker.TestHelper.slack_rtm())

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == @some_users_names_list

    TaskerHelper.remove_users_from_group("<@user2> <@user3>", @group_name_group_1, Tasker.TestHelper.slack_rtm())

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.users == ["user1", "user4"]
  end

  test "remove a group from the cache" do
    TaskerHelper.create_users_group(@some_users_slack_ids, @group_name_group_1, Tasker.TestHelper.slack_rtm())

    TestHelper.get_cached_group(@group_name_group_1)

    TaskerHelper.remove_group(@group_name_group_1)

    assert_raise(NoResultFound, fn -> TestHelper.get_cached_group(@group_name_group_1) end)
  end

  test "get slack users from a user ids string" do
    slack_users = TaskerHelper.get_slack_users(@some_users_slack_ids, Tasker.TestHelper.slack_rtm())

    assert slack_users == Tasker.TestHelper.slack_rtm_users()
  end

  test "get slack users from a user ids string that doesnt exists" do
    slack_users = TaskerHelper.get_slack_users("<@u11> <@u22> <@asdasds> <@asd45as23>", Tasker.TestHelper.slack_rtm())

    assert slack_users == %{}
  end

  test "get slack users from a user ids string where some exist and some not" do
    slack_users = TaskerHelper.get_slack_users("<@user1> <@u11> <@u22> <@user3> <@asd45as23> <@user3>", Tasker.TestHelper.slack_rtm())

    assert slack_users == %{"user1" => %{id: "user1", is_bot: false}, "user3" => %{id: "user3", is_bot: false}}
  end
end
