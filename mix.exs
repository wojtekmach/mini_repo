defmodule MiniRepo.MixProject do
  use Mix.Project

  def project() do
    [
      app: :mini_repo,
      version: "0.2.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: releases()
    ]
  end

  def application() do
    [
      extra_applications: [:crypto, :inets, :ssl],
      mod: {MiniRepo.Application, []}
    ]
  end

  defp deps() do
    [
      {:hex_core, "~> 0.5.0"},

      # plug
      {:plug, "~> 1.0"},
      {:plug_cowboy, "~> 2.0"},

      # s3
      {:ex_aws, "~> 2.0"},
      {:ex_aws_s3, "~> 2.0"},
      {:hackney, "~> 1.9"},
      {:jason, "~> 1.0"}
    ]
  end

  defp aliases() do
    [
      test: ["test --no-start"]
    ]
  end

  defp releases() do
    [
      mini_repo: [
        steps: [:assemble, &copy_runtime_exs/1],
        config_providers: [{Config.Reader, {:system, "RELEASE_ROOT", "/config/runtime.exs"}}]
      ]
    ]
  end

  # see config/runtime.exs
  defp copy_runtime_exs(release) do
    File.mkdir!(Path.join(release.path, "config"))
    local_path = Path.join([__DIR__, "config", "runtime.exs"])
    release_path = Path.join([release.path, "config", "runtime.exs"])
    File.cp!(local_path, release_path)
    release
  end
end
