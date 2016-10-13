defmodule Tasker do
  use Application

  # :observer.start

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    slack_token = Application.get_env(:tasker, Tasker.SlackBot)[:token]

    # Define workers and child supervisors to be supervised
    children = [
      worker(Tasker.SlackBot, [slack_token], [name: SlackBot, restart: :transient]),
      worker(ConCache, [[], [name: :task_stuff_cache]])
    ]

    opts = [strategy: :one_for_one, name: Tasker.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
