defmodule Tasker.Mixfile do
  use Mix.Project

  def project do
    [app: :tasker,
     version: "0.2.6",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :slack, :con_cache, :quantum],
     mod: {Tasker, []}]
  end

  defp deps do
    [
      {:plug, "~> 1.4.3"},
      {:slack, "~> 0.12.0"},
      {:con_cache, "~> 0.11.1"},
      {:quantum, "~> 1.8.0"}
    ]
  end
end
