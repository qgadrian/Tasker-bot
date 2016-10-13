use Mix.Config

# Get slack token from system env
config :tasker, Tasker.SlackBot,
  token: System.get_env("SLACK_TOKEN")
