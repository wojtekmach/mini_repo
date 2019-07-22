defmodule MiniRepo.Mirror.Server do
  @moduledoc false

  use GenServer
  require Logger
  alias MiniRepo.{RegistryDiff, RegistryBackup}

  def start_link(options) do
    {mirror, options} = Keyword.pop(options, :mirror)
    GenServer.start_link(__MODULE__, mirror, options)
  end

  @impl true
  def init(mirror) do
    mirror = RegistryBackup.load(mirror)
    {:ok, mirror, {:continue, :sync}}
  end

  @impl true
  def handle_continue(:sync, mirror) do
    handle_info(:sync, mirror)
  end

  @impl true
  def handle_info(:sync, mirror) do
    case sync(mirror) do
      {:ok, %MiniRepo.Mirror{} = new_mirror} ->
        schedule_sync(new_mirror)
        {:noreply, new_mirror}

      _ ->
        schedule_sync(mirror)
        {:noreply, mirror}
    end
  end

  defp schedule_sync(mirror) do
    Process.send_after(self(), :sync, mirror.sync_interval)
  end

  defp sync(mirror) do
    config = %{
      :hex_core.default_config()
      | repo_name: mirror.upstream_name,
        repo_url: mirror.upstream_url,
        repo_public_key: mirror.upstream_public_key,
        http_user_agent_fragment: user_agent_fragment()
    }

    with {:ok, names} when is_list(names) <- sync_names(mirror, config),
         {:ok, versions} when is_list(versions) <- sync_versions(mirror, config) do
      versions =
        for %{name: name} = map <- versions,
            !mirror.only or name in mirror.only,
            into: %{},
            do: {name, Map.delete(map, :version)}

      diff = RegistryDiff.diff(mirror.registry, versions)
      Logger.debug [inspect(__MODULE__), " diff: ", inspect(diff, pretty: true)]
      created = sync_created_packages(mirror, config, diff)
      deleted = sync_deleted_packages(mirror, config, diff)
      updated = sync_releases(mirror, config, diff)

      mirror =
        update_in(mirror.registry, fn registry ->
          registry
          |> Map.delete(deleted)
          |> Map.merge(created)
          |> Map.merge(updated)
        end)

      RegistryBackup.save(mirror)
      {:ok, mirror}
    end
  end

  defp sync_created_packages(mirror, config, diff) do
    stream =
      Task.Supervisor.async_stream_nolink(
        MiniRepo.TaskSupervisor,
        diff.packages.created,
        fn name ->
          {:ok, releases} = sync_package(mirror, config, name)

          Task.Supervisor.async_stream_nolink(
            MiniRepo.TaskSupervisor,
            releases,
            fn release ->
              :ok = sync_tarball(mirror, config, name, release.version)
            end,
            ordered: false
          )
          |> Stream.run()

          {name, releases}
        end,
        ordered: false
      )

    for {:ok, {name, releases}} <- stream, into: %{} do
      {name, releases}
    end
  end

  defp sync_deleted_packages(mirror, _config, diff) do
    for name <- diff.packages.deleted do
      for %{version: version} <- mirror.registry[name] do
        store_delete(mirror, ["tarballs", "#{name}-#{version}.tar"])
      end

      name
    end
  end

  defp sync_releases(mirror, config, diff) do
    stream =
      Task.Supervisor.async_stream_nolink(MiniRepo.TaskSupervisor, diff.releases, fn {name, map} ->
        {:ok, releases} = sync_package(mirror, config, name)

        Task.Supervisor.async_stream_nolink(
          MiniRepo.TaskSupervisor,
          map.created,
          fn version ->
            :ok = sync_tarball(mirror, config, name, version)
          end,
          ordered: false
        )
        |> Stream.run()

        for version <- map.deleted do
          store_delete(mirror, ["tarballs", "#{name}-#{version}.tar"])
        end

        {name, releases}
      end)

    for {:ok, {name, releases}} <- stream, into: %{} do
      {name, releases}
    end
  end

  # we don't use this resource for anything, we just copy it (since it's signed by upstream)
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

  defp sync_tarball(mirror, config, name, version) do
    with {:ok, {200, _headers, tarball}} <- fetch_tarball(config, name, version),
         :ok <- store_put(mirror, ["tarballs", "#{name}-#{version}.tar"], tarball) do
      :ok
    else
      other ->
        Logger.warn("#{inspect(__MODULE__)} sync_tarball failed: #{inspect(other)}")
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
    {:ok, payload} = decode_and_verify_signed(body, mirror)
    :hex_registry.decode_names(payload, mirror.upstream_name)
  end

  defp decode_versions(mirror, body) do
    {:ok, payload} = decode_and_verify_signed(body, mirror)
    :hex_registry.decode_versions(payload, mirror.upstream_name)
  end

  defp decode_package(mirror, body, name) do
    {:ok, payload} = decode_and_verify_signed(body, mirror)
    :hex_registry.decode_package(payload, mirror.upstream_name, name)
  end

  defp decode_and_verify_signed(body, mirror) do
    :hex_registry.decode_and_verify_signed(:zlib.gunzip(body), mirror.upstream_public_key)
  end

  defp user_agent_fragment() do
    {:ok, vsn} = :application.get_key(:mini_repo, :vsn)
    "mini_repo/#{vsn}"
  end

  defp store_put(mirror, path, contents) do
    MiniRepo.Store.put(mirror.store, ["repos", mirror.name] ++ List.wrap(path), contents)
  end

  defp store_delete(repository, name) do
    MiniRepo.Store.delete(repository.store, name)
  end
end
