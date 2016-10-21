# Tasker

**Slack bot to manage tasks**

This Slack bot manages tasks and users/groups to do a desired task. When a user marks a task as done, he/she will be removed from the remaining users list.

Once a task has no remaining users, it will be deleted.

A task can be deleted even if there are remaining users.

You can use the bot both by an im or mention in any channel the bot is member.

Notifications might be configured for all remaining tasks or just for a desired ones. The notification may be in a channel (bot has to be member of the notification channel) or by a im to every remaining user.

This bot uses the library [Elixir-Slack](https://github.com/BlakeWilliams/Elixir-Slack).

The bot following will work with the following commands:

  * Create a new task

  ``` @taskerBot Task new TASK_NAME @user1 @user2 ```

  ``` @taskerBot Task new TASK_NAME GROUP_NAME ```

  * Remove a task

  ``` @taskerBot Task remove TASK_NAME ```

  ``` @taskerBot Task delete TASK_NAME ```

  * Rename a task

  ``` @taskerBot Task TASK_NAME rename to NEW_TASK_NAME ```

  * Mark a task as done

  (current user)

  ``` @taskerBot Task TASK_NAME done ```

  (mark a entire group as done)

  ``` @taskerBot Task TASK_NAME MY_TASK_GROUP done ```

  (mark other users as done)

  ``` @taskerBot Task TASK_NAME @user1 @user2 done ```

  * List current taks and the remaining users

  ``` @taskerBot Tasks ```

  * Create an user group

  ``` @taskerBot Group new GROUP_NAME @user1 @user2 ```

  * Remove an user group

  ``` @taskerBot Group remove GROUP_NAME ```

  * Add a users to a group

  ``` @taskerBot Group GROUP_NAME add @user3 @user4 ```

  * Remove users from a group

  ``` @taskerBot Group GROUP_NAME remove @user1 @user2 ```

  ``` @taskerBot Group GROUP_NAME delete @user1 @user2 ```

  * List groups and members

  ``` @taskerBot Groups ```

  * Notify all remaining tasks on channel

  ``` @taskerBot Task notify all on #channel_name * * * * * ```

  * Notify remaining task on channel

  ``` @taskerBot Task notify TASK_NAME on #channel_name * * * * * ```

  * Notify remaining task to all remaining users by im's

  ``` @taskerBot Task notify TASK_NAME on * * * * * ```

## Running

Just set your slack bot token in the system env:

  ``` export SLACK_TOKEN=my_token ```

Install dependencies:

  ``` mix deps.get ```

And run the bot using:

``` mix run --no-halt ```
