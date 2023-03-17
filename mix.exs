defmodule DataClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :data_client,
      version: "0.2.4",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:limited_queue, "~> 0.1.0"},
      {:httpoison, "~> 1.8"},
      {:jason, "~> 1.2"},
      {:shorter_maps, git: "https://github.com/boyzwj/shorter_maps.git", tag: "master"}
    ]
  end
end
