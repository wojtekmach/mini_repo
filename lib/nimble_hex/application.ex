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

    endpoint_spec =
      Plug.Cowboy.child_spec(
        plug: {NimbleHex.Endpoint, config},
        scheme: :http,
        options: http_options
      )

    children = repository_and_mirror_specs(config) ++ [endpoint_spec]
    opts = [strategy: :one_for_one, name: NimbleHex.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp repository_and_mirror_specs(config) do
    for {name, options} <- Keyword.fetch!(config, :repositories) do
      if options[:upstream_url] do
        mirror = struct!(NimbleHex.Mirror, [name: to_string(name)] ++ options)
        {NimbleHex.Mirror.Server, mirror: mirror, name: name}
      else
        repository = struct!(NimbleHex.Repository, [name: to_string(name)] ++ options)
        {NimbleHex.Repository.Server, repository: repository, name: name}
      end
    end
  end
end
