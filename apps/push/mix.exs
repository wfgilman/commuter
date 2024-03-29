defmodule Push.MixProject do
  use Mix.Project

  def project do
    [
      app: :push,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Push, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:pigeon, "~> 1.2.3"},
      {:kadabra, "~> 0.4.3"},
      {:core, in_umbrella: true},
      {:shared, in_umbrella: true}
    ]
  end
end
