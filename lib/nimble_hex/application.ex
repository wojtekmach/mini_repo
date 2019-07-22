defmodule NimbleHex.Application do
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    config = Application.get_all_env(:nimble_hex)

    http_options = [
      port: Keyword.fetch!(config, :port)
    ]

    Logger.info("Starting Cowboy with #{inspect(http_options)}")

    repos = repositories(config)
    regular_repos = for %NimbleHex.Repository{} = repo <- repos, do: repo.name

    router_opts = [
      url: config[:url],
      repositories: regular_repos
    ]

    endpoint_spec =
      Plug.Cowboy.child_spec(
        plug: {NimbleHex.Endpoint, router_opts},
        scheme: :http,
        options: http_options
      )

    task_supervisor = {Task.Supervisor, name: NimbleHex.TaskSupervisor}
    children = [task_supervisor] ++ repository_specs(repos) ++ [endpoint_spec]
    opts = [strategy: :one_for_one, name: NimbleHex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp repositories(config) do
    for {name, options} <- Keyword.fetch!(config, :repositories) do
      if options[:upstream_url] do
        struct!(NimbleHex.Mirror, [name: to_string(name)] ++ options)
      else
        struct!(NimbleHex.Repository, [name: to_string(name)] ++ options)
      end
    end
  end

  defp repository_specs(repos), do: Enum.map(repos, &repository_spec/1)

  defp repository_spec(%NimbleHex.Mirror{} = repo),
    do: {NimbleHex.Mirror.Server, mirror: repo, name: String.to_atom(repo.name)}

  defp repository_spec(%NimbleHex.Repository{} = repo),
    do: {NimbleHex.Repository.Server, repository: repo, name: String.to_atom(repo.name)}
end
