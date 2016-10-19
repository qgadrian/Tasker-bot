# Tasker

**Slack bot to manage tasks**

This Slack bot manages tasks and users/groups to do a desired task. When a user marks a task as done, he/she will be removed from the remaining users list.

Once a task has no remaining users, it will be deleted.

A task can be deleted even if there are remaining users.

You can use the bot both by an im or mention in any channel the bot is member.

This bot uses the library [Elixir-Slack](https://github.com/BlakeWilliams/Elixir-Slack).

The bot following will work with the following commands:

  * Create a new task

  ``` @taskerBot Task new MY_TASK_NAME @user1 @user2 ```

  ``` @taskerBot Task new MY_TASK_NAME MY_GROUP_NAME ```

  * Remove a task

  ``` @taskerBot Task remove MY_TASK_NAME ```

  ``` @taskerBot Task delete MY_TASK_NAME ```

  * Rename a task

  ``` @taskerBot Task MY_TASK_NAME rename to MY_NEW_TASK_NAME ```

  * Mark a task as done

  (current user)

  ``` @taskerBot Task MY_TASK_NAME done ```

  (mark a entire group as done)

  ``` @taskerBot Task MY_TASK_NAME MY_TASK_GROUP done ```

  (mark other users as done)

  ``` @taskerBot Task MY_TASK_NAME @user1 @user2 done ```

  * List current taks and the remaining users

  ``` @taskerBot Tasks ```

  * Create an user group

  ``` @taskerBot Group new MY_GROUP_NAME @user1 @user2 ```

  * Add a users to a group

  ``` @taskerBot Group MY_GROUP_NAME add @user3 @user4 ```

  * Remove users from a group

  ``` @taskerBot Group MY_GROUP_NAME remove @user1 @user2 ```

  ``` @taskerBot Group MY_GROUP_NAME delete @user1 @user2 ```

  * List groups and members

  ``` @taskerBot Groups ```

## Running

Just set your slack bot token in the system env:

  ``` export SLACK_TOKEN=my_token ```

Install dependencies:

  ``` mix deps.get ```

And run the bot using:

``` mix run --no-halt ```
