defmodule NimbleHex.Mirror.Server do
  @moduledoc false

  use GenServer
  require Logger

  def start_link(options) do
    {mirror, options} = Keyword.pop(options, :mirror)
    GenServer.start_link(__MODULE__, mirror, options)
  end

  @impl true
  def init(mirror) do
    {:ok, mirror, {:continue, :sync}}
  end

  @impl true
  def handle_continue(:sync, mirror) do
    handle_info(:sync, mirror)
  end

  @impl true
  def handle_info(:sync, mirror) do
    sync(mirror)
    schedule_sync(mirror)
    {:noreply, mirror}
  end

  defp schedule_sync(mirror) do
    Process.send_after(self(), :sync, mirror.sync_interval)
  end

  defp sync(mirror) do
    # TODO: currently sync is naive and downloads everything everytime.

    config = %{
      :hex_core.default_config()
      | repo_name: mirror.mirror_name,
        repo_url: mirror.mirror_url,
        repo_public_key: mirror.public_key,
        http_user_agent_fragment: user_agent_fragment()
    }

    with {:ok, names} when is_list(names) <- sync_names(mirror, config),
         {:ok, versions} when is_list(versions) <- sync_versions(mirror, config) do
      for %{name: name} <- names,
          !mirror.only or name in mirror.only do
        sync_package(mirror, config, name)
      end

      for %{name: name, versions: versions} <- versions,
          !mirror.only or name in mirror.only,
          version <- versions do
        sync_release(mirror, config, name, version)
      end

      # TODO: sync docs?
    end
  end

  defp sync_names(mirror, config) do
    with {:ok, {200, _, names_signed}} <- fetch_names(config),
         {:ok, names} <- decode_names(mirror, names_signed),
         :ok <- store_put(mirror, "names", names_signed) do
      {:ok, names}
    else
      other ->
        Logger.warn("#{inspect(__MODULE__)} sync_names failed: #{inspect(other)}")
        other
    end
  end

  defp sync_versions(mirror, config) do
    with {:ok, {200, _, signed}} <- fetch_versions(config),
         {:ok, versions} <- decode_versions(mirror, signed),
         :ok <- store_put(mirror, "versions", signed) do
      {:ok, versions}
    else
      other ->
        Logger.warn("#{inspect(__MODULE__)} sync_versions failed: #{inspect(other)}")
        other
    end
  end

  defp sync_package(mirror, config, name) do
    with {:ok, {200, _, signed}} <- fetch_package(config, name),
         {:ok, package} <- decode_package(mirror, signed, name),
         :ok <- store_put(mirror, ["packages", name], signed) do
      {:ok, package}
    else
      other ->
        Logger.warn("#{inspect(__MODULE__)} sync_package failed: #{inspect(other)}")
        other
    end
  end

  defp sync_release(mirror, config, name, version) do
    with {:ok, {200, _headers, tarball}} <- fetch_tarball(config, name, version),
         :ok <- store_put(mirror, ["tarballs", "#{name}-#{version}.tar"], tarball) do
      :ok
    else
      other ->
        Logger.warn("#{inspect(__MODULE__)} sync_release failed: #{inspect(other)}")
        other
    end
  end

  defp fetch_names(config) do
    Logger.debug("#{inspect(__MODULE__)} fetching names")
    :hex_http.request(config, :get, config.repo_url <> "/names", %{}, :undefined)
  end

  defp fetch_versions(config) do
    Logger.debug("#{inspect(__MODULE__)} fetching versions")
    :hex_http.request(config, :get, config.repo_url <> "/versions", %{}, :undefined)
  end

  defp fetch_package(config, name) do
    Logger.debug("#{inspect(__MODULE__)} fetching package #{name}")
    :hex_http.request(config, :get, config.repo_url <> "/packages/" <> name, %{}, :undefined)
  end

  defp fetch_tarball(config, name, version) do
    Logger.debug("#{inspect(__MODULE__)} fetching tarball #{name}-#{version}.tar")
    :hex_repo.get_tarball(config, name, version)
  end

  defp decode_names(mirror, body) do
    {:ok, payload} = :hex_registry.decode_and_verify_signed(:zlib.gunzip(body), mirror.public_key)
    :hex_registry.decode_names(payload, mirror.mirror_name)
  end

  defp decode_versions(mirror, body) do
    {:ok, payload} = :hex_registry.decode_and_verify_signed(:zlib.gunzip(body), mirror.public_key)
    :hex_registry.decode_versions(payload, mirror.mirror_name)
  end

  defp decode_package(mirror, body, name) do
    {:ok, payload} = :hex_registry.decode_and_verify_signed(:zlib.gunzip(body), mirror.public_key)
    :hex_registry.decode_package(payload, mirror.mirror_name, name)
  end

  defp user_agent_fragment() do
    {:ok, vsn} = :application.get_key(:nimble_hex, :vsn)
    "nimble_hex/#{vsn}"
  end

  defp store_put(mirror, path, contents) do
    NimbleHex.Store.put(mirror.store, ["repos", mirror.name] ++ List.wrap(path), contents)
  end
end
