defmodule Tasker.NotificationHelper do
  use Slack

  import Tasker.CacheHelper
  import Tasker.MessageHelper

  def notify_task_to_remaining_users(task_name, channel, slack) do
    Logger.debug "Notifying to channel #{channel}"
    Enum.each(get_cached_tasks(), fn(task) ->
      remaining_users = get_multiple_users_string_list(task.users)
      send_message("#{remaining_users} remember you have pending task *#{task_name}*", channel, slack)
    end)
  end

  def notify_task_to_remaining_users(:im, slack) do
    Logger.debug "Notifying to im's"
    notifify_tasks_by_im(get_cached_tasks(), slack)
  end

  defp notifify_tasks_by_im(tasks, slack) do
    Enum.each(tasks, fn(task) ->
      notify_user_by_im(task.users, task.name, slack)
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
