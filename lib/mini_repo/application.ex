defmodule MiniRepo.Application do
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    config = Application.get_all_env(:mini_repo)

    http_options = [
      port: Keyword.fetch!(config, :port)
    ]

    Logger.info("Starting Cowboy with #{inspect(http_options)}")

    repos = repositories(config)
    regular_repos = for %MiniRepo.Repository{} = repo <- repos, do: repo.name

    router_opts = [
      url: config[:url],
      repositories: regular_repos
    ]

    endpoint_spec =
      Plug.Cowboy.child_spec(
        plug: {MiniRepo.Endpoint, router_opts},
        scheme: :http,
        options: http_options
      )

    task_supervisor = {Task.Supervisor, name: MiniRepo.TaskSupervisor}
    children = [task_supervisor] ++ repository_specs(repos) ++ [endpoint_spec]
    opts = [strategy: :one_for_one, name: MiniRepo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp repositories(config) do
    for {name, options} <- Keyword.fetch!(config, :repositories) do
      cond do
        !is_nil(options[:upstream_url]) and !is_nil(options[:on_demand]) -> struct!(MiniRepo.MirrorOnDemand, [name: to_string(name)] ++ options)
        options[:upstream_url] -> struct!(MiniRepo.Mirror, [name: to_string(name)] ++ options)
        true ->struct!(MiniRepo.Repository, [name: to_string(name)] ++ options)
      end
    end
  end

  defp repository_specs(repos), do: Enum.map(repos, &repository_spec/1)


  defp repository_spec(%MiniRepo.MirrorOnDemand{} = repo),
    do: {MiniRepo.Mirror.ServerOnDemand, mirror: repo, name: String.to_atom(repo.name)}

  defp repository_spec(%MiniRepo.Mirror{} = repo),
    do: {MiniRepo.Mirror.Server, mirror: repo, name: String.to_atom(repo.name)}

  defp repository_spec(%MiniRepo.Repository{} = repo),
    do: {MiniRepo.Repository.Server, repository: repo, name: String.to_atom(repo.name)}
end
