use Mix.Config

# Get slack token from system env
config :tasker, Tasker,
  token: System.get_env("SLACK_TOKEN")

config :quantum,
  timezone: :local

import_config "#{Mix.env}.exs"
