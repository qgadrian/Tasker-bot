defmodule TaskerTest do
  use ExUnit.Case
  doctest Tasker

  alias Tasker.{TestHelper, TaskerHelper}

  @task_name_task_1 "task_1"
  @group_name_group_1 "group_1"
  @task_creation_timestamp "23"
  @some_users_slack_ids "<@user1> <@user2> <@user3>"
  @some_users_names_list ["user1", "user2", "user3"]

  setup do
    Supervisor.terminate_child(Tasker.Supervisor, ConCache)
    Supervisor.restart_child(Tasker.Supervisor, ConCache)
    :ok
  end

# Task tests
  test "create new task with some users" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp)

    cached_caches = ConCache.get(:tasker_cache, :tasks)

    assert Enum.any?(cached_caches, fn(cached_task) -> cached_task.name == @task_name_task_1 end)
  end

  test "create new task with all users" do
    TaskerHelper.create_task_for_users(Tasker.TestHelper.slack_rtm().users, @task_name_task_1, @task_creation_timestamp)

    cached_caches = ConCache.get(:tasker_cache, :tasks)

    assert Enum.all?(cached_caches, fn(cached_task) ->
      Enum.all?(cached_task.users, fn(cached_user) ->
        Enum.any?(Tasker.TestHelper.slack_rtm().slack_users, fn({slack_user_name, _}) ->
          cached_user == slack_user_name
        end)
      end)
    end)
  end

  test "create new task with a name that already exists using user names" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp)

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.name == @task_name_task_1
    assert cached_task.users == @some_users_names_list

    assert :error == TaskerHelper.create_task_for_users("<@user5> <@user6>", @task_name_task_1, @task_creation_timestamp)
  end

  test "create new task with a name that already exists using all users" do
    TaskerHelper.create_task_for_users(Tasker.TestHelper.slack_rtm().users, @task_name_task_1, @task_creation_timestamp)

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.name == @task_name_task_1
    assert cached_task.users == TestHelper.slack_rtm_users_id_list

    assert :error == TaskerHelper.create_task_for_users("<@user5> <@user6>", @task_name_task_1, @task_creation_timestamp)
  end

  test "create new task with a name that already exists using a group" do
    TaskerHelper.create_task_for_users(Tasker.TestHelper.slack_rtm().users, @task_name_task_1, @task_creation_timestamp)

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.name == @task_name_task_1
    assert cached_task.users == TestHelper.slack_rtm_users_id_list

    TaskerHelper.create_users_group("<@user5>", @group_name_group_1)

    assert :error == TaskerHelper.create_task_for_group(@group_name_group_1, @task_name_task_1, @task_creation_timestamp)
  end

  test "mark a task as done by the current user" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp)

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.users == @some_users_names_list

    TaskerHelper.do_task(@task_name_task_1, "<@user1>", :users)

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.users == ["user2", "user3"]
  end

  test "mark a task as done by some users" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp)

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.users == @some_users_names_list

    TaskerHelper.do_task(@task_name_task_1, "<@user1> <@user2>", :users)

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.users == ["user3"]
  end

  test "mark a task as done by an entire group" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp)
    TaskerHelper.create_users_group("<@user1> <@user2>", @group_name_group_1)

    TaskerHelper.do_task(@task_name_task_1, @group_name_group_1, :group)

    cached_task = TestHelper.get_cached_task(@task_name_task_1)

    assert cached_task.users == ["user3"]
  end

  test "a task is removed when its mark as done by all of its users" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp)

    TestHelper.get_cached_task(@task_name_task_1)

    TaskerHelper.do_task(@task_name_task_1, "<@user1> <@user2> <@user3>", :users)

    assert_raise(NoResultFound, fn -> TestHelper.get_cached_task(@task_name_task_1) end)
  end

  test "remove a task" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp)

    TestHelper.get_cached_task(@task_name_task_1)

    TaskerHelper.remove_task(@task_name_task_1)

    assert_raise(NoResultFound, fn -> TestHelper.get_cached_task(@task_name_task_1) end)
  end

  test "rename a task" do
    TaskerHelper.create_task_for_users(@some_users_slack_ids, @task_name_task_1, @task_creation_timestamp)

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
    assert cached_group.users == Map.keys(TestHelper.slack_rtm().slack_users)
  end

  test "create new user group with some users" do
    TaskerHelper.create_users_group(@some_users_slack_ids, @group_name_group_1)

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == @some_users_names_list
  end

  test "create new user group with a name that already exists" do
    TaskerHelper.create_users_group(Tasker.TestHelper.slack_rtm().users, @group_name_group_1)

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == Map.keys(TestHelper.slack_rtm().slack_users)

    assert :error == TaskerHelper.create_users_group("<@user23>", @group_name_group_1)
  end

  test "add a user from a group" do
    TaskerHelper.create_users_group(@some_users_slack_ids, @group_name_group_1)

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == @some_users_names_list

    TaskerHelper.add_users_to_group("<@user4>", @group_name_group_1)

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.users == (@some_users_names_list ++ ["user4"])
  end

  test "remove a user from a group" do
    TaskerHelper.create_users_group(@some_users_slack_ids, @group_name_group_1)

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == @some_users_names_list

    TaskerHelper.remove_users_from_group("<@user1>", @group_name_group_1)

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.users == ["user2", "user3"]
  end

  test "remove various users from a group" do
    TaskerHelper.create_users_group(@some_users_slack_ids, @group_name_group_1)

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.name == @group_name_group_1
    assert cached_group.users == @some_users_names_list

    TaskerHelper.remove_users_from_group("<@user2> <@user3>", @group_name_group_1)

    cached_group = TestHelper.get_cached_group(@group_name_group_1)

    assert cached_group.users == ["user1"]
  end

  test "remove a group from the cache" do
    TaskerHelper.create_users_group(@some_users_slack_ids, @group_name_group_1)

    TestHelper.get_cached_group(@group_name_group_1)

    TaskerHelper.remove_group(@group_name_group_1)

    assert_raise(NoResultFound, fn -> TestHelper.get_cached_group(@group_name_group_1) end)
  end
end
