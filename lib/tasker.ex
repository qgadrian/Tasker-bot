defmodule Tasker do
  use Application

  # :observer.start
  # c("lib/slack/slack.ex")

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    slack_token = Application.get_env(:tasker, Tasker)[:token]

    default_workers = [worker(ConCache, [[], [name: :tasker_cache]])]

    # Define workers and child supervisors to be supervised
    children =
      case Application.get_env(:tasker, :enable_tasker_worker, false) do
        true ->
          [worker(Tasker.SlackBot, [slack_token], [name: :tasker_bot, restart: :transient])] ++ default_workers
        false -> default_workers
      end


    opts = [strategy: :one_for_one, name: Tasker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
