defmodule Tasker.NotificationHelper do
  use Slack

  require Logger

  import Tasker.CacheHelper
  import Tasker.MessageHelper

  def notify_task_to_remaining_users(:all_tasks, :im, slack) do
    Logger.debug "Notifying to im's about all tasks"
    notifify_tasks_by_im(get_cached_tasks(), slack)
  end

  def notify_task_to_remaining_users(:all_tasks, channel, slack) do
    Logger.debug "Notifying to channel #{channel} about all tasks"
    Enum.each(get_cached_tasks(), fn(task) ->
      remaining_users = get_multiple_users_string_list(task.users)
      send_message("#{remaining_users} remember you have pending task *#{task.name}*", channel, slack)
    end)
  end

  def notify_task_to_remaining_users(task_name, :im, slack) do
    Logger.debug "Notifying to im's about #{task_name}"
    notifify_task_by_im(task_name, get_cached_tasks(), slack)
  end

  def notify_task_to_remaining_users(task_name, channel, slack) do
    Logger.debug "Notifying to channel #{channel} about #{task_name}"
    Enum.each(get_cached_tasks(), fn(task) ->
      cond do
         task.name == task_name ->
           remaining_users = get_multiple_users_string_list(task.users)
           send_message("#{remaining_users} remember you have pending task *#{task_name}*", channel, slack)
      end
    end)
  end

  defp notifify_tasks_by_im(tasks, slack) do
    Enum.each(tasks, fn(task) ->
        notify_user_by_im(task.users, task.name, slack)
    end)
  end

  defp notifify_task_by_im(task_name, tasks, slack) do
    Enum.each(tasks, fn(task) ->
      cond do
        task.name == task_name -> notify_user_by_im(task.users, task.name, slack)
      end
    end)
  end

  defp notify_user_by_im(user_names, task_name, slack) do
    Enum.each(user_names, fn(user_name) ->
      im_channel = get_im_channel(user_name, slack).id
      send_message("<@#{user_name}> remember you have pending task *#{task_name}*", im_channel, slack)
    end)
  end

  defp get_im_channel(user_name, slack) do
    Enum.find(Map.values(slack.ims), fn(im) ->
      im.user == user_name
    end)
  end
end
