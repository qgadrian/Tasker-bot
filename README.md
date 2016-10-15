# Tasker

**Slack bot to manage tasks**

This Slack bot manages tasks and users/groups to do a desired task. When a user marks a task as done, he/she will be removed from the remaining users list.

Once a task has no remaining users, it will be deleted.

This bot uses the library [Elixir-Slack](https://github.com/BlakeWilliams/Elixir-Slack).

The bot following will work with the following commands:

  * Create a new task

  ``` @taskerBot Task new MY_TASK_NAME @user1 @user2 ```

  ``` @taskerBot Task new MY_TASK_NAME MY_GROUP_NAME ```

  * Mark a task as done

  ``` @taskerBot Task MY_TASK_NAME done ```

  * List current taks and the remaining users

  ``` @taskerBot Tasks ```

  * Create an user group

  ``` @taskerBot Group new MY_GROUP_NAME @user1 @user2 ```

  * Add a users to a group

  ``` @taskerBot Group MY_GROUP_NAME add @user3 @user4 ```

  * Remove users from a group

  ``` @taskerBot Group MY_GROUP_NAME remove @user1 @user2 ```

  * List groups and members

  ``` @taskerBot Groups ```

## Running

Just set your slack bot token in the system env:

  ``` export SLACK_TOKEN=my_token ```

And run the bot using

``` mix run --no-halt ```
