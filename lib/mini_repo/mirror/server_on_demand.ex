defmodule MiniRepo.Mirror.ServerOnDemand do
  @moduledoc false

  use GenServer
  require Logger
  alias MiniRepo.{RegistryDiff, RegistryBackup}

  @default_sync_opts [ordered: false]

  def start_link(options) do
    {mirror, options} = Keyword.pop(options, :mirror)
    GenServer.start_link(__MODULE__, mirror, options)
  end

  @impl true
  def init(mirror) do
    Logger.info("#{__MODULE__}" <> " Starting Up.")
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

  defp get_config_from_mirror(mirror) do
    %{
      :hex_core.default_config()
      | repo_name: mirror.upstream_name,
        repo_url: mirror.upstream_url,
        repo_public_key: mirror.upstream_public_key,
        http_user_agent_fragment: user_agent_fragment()
    }
  end

  defp get_packages_on_disk(mirror) do
    mirror.registry
    |> Map.to_list()
    |> Enum.map(fn {name, _} -> name end)
  end

  defp diff_packages_on_disk(mirror, config) do
    get_packages_on_disk(mirror)
    |> diff_packages(mirror, config)
  end

  defp diff_packages(package_list, mirror, config) do
    with {:ok, names} when is_list(names) <- sync_names(mirror, config),
         {:ok, versions} when is_list(versions) <- sync_versions(mirror, config) do
      versions =
        for %{name: name} = map <- versions,
            name in package_list,
            into: %{},
            do: {name, Map.delete(map, :version)}

      {:ok, RegistryDiff.diff(mirror.registry, versions)}
    end
  end

  defp sync(mirror) do
    Logger.debug("Sync/1 Running #{__MODULE__}")
    config = get_config_from_mirror(mirror)

    with {:ok, diff} <- diff_packages_on_disk(mirror, config) do
      Logger.debug([inspect(__MODULE__), " diff: ", inspect(diff, pretty: true)])
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

  def fetch_package_if_not_exist(name) do
    get_pid()
    |> GenServer.call({:package_exist, name}, 30_000)
    |> put_package(name)
  end

  def fetch_tarball_if_not_exist(name, version) do
    get_pid()
    |> GenServer.call({:package_exist, name}, 30_000)
    |> put_tarball(name, version)
  end

  @impl true
  def handle_call({:package_exist, name}, _from, mirror) do
    packages = get_packages_on_disk(mirror)
    exist = Enum.member?(packages, name)

    {:reply, exist, mirror}
  end

  def put_package(_exist = false, name) do
    GenServer.whereis(:hexpm_mirror)
    |> GenServer.call({:put_package, name}, 30_000)
  end

  def put_package(_exist = true, _name) do
    :ok
  end

  def put_tarball(_exist = false, name, version) do
    GenServer.whereis(:hexpm_mirror)
    |> GenServer.call({:put_tarball, name, version}, 30_000)
  end

  def put_tarball(_exist = true, _name, _versio) do
    :ok
  end

  @impl true
  def handle_call({:put_package, name}, _from, mirror) do
    {:ok, _releases} = sync_package(mirror, get_config_from_mirror(mirror), name)
    {:reply, :ok, mirror}
  end

  defp get_pid() do
    GenServer.whereis(:hexpm_mirror)
  end

  def handle_call({:put_tarball, name, version}, _from, mirror) do
    new_mirror = sync_package_version(mirror, get_config_from_mirror(mirror), name, version)
    {:reply, :ok, new_mirror}
  end

  defp sync_created_packages(mirror, config, diff) do
    mirror_sync_opts = Keyword.merge(@default_sync_opts, mirror.sync_opts)

    stream =
      Task.Supervisor.async_stream_nolink(
        MiniRepo.TaskSupervisor,
        diff.packages.created,
        fn name ->
          {:ok, releases} = sync_package(mirror, config, name)

          stream =
            Task.Supervisor.async_stream_nolink(
              MiniRepo.TaskSupervisor,
              releases,
              fn release ->
                :ok = sync_tarball(mirror, config, name, release.version)
                release
              end,
              mirror_sync_opts
            )

          releases = for {:ok, release} <- stream, do: release
          {name, releases}
        end,
        mirror_sync_opts
      )

    for {:ok, {name, releases}} <- stream, into: %{} do
      {name, releases}
    end
  end

  defp sync_package_version(mirror, config, name, version) do
    {:ok, releases} = sync_package(mirror, config, name)

    :ok = sync_tarball(mirror, config, name, version)

    created =
      Enum.filter(releases, fn r -> r.version == version end)
      |> Enum.map(fn r -> {name, [r]} end)
      |> Enum.into(%{})

    mirror =
      update_in(mirror.registry, fn registry ->
        registry
        |> Map.merge(created)
      end)

    RegistryBackup.save(mirror)
    mirror
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
    mirror_sync_opts = Keyword.merge(@default_sync_opts, mirror.sync_opts)

    stream =
      Task.Supervisor.async_stream_nolink(
        MiniRepo.TaskSupervisor,
        diff.releases,
        fn {name, map} ->
          {:ok, releases} = sync_package(mirror, config, name)

          Task.Supervisor.async_stream_nolink(
            MiniRepo.TaskSupervisor,
            map.created,
            fn version ->
              :ok = sync_tarball(mirror, config, name, version)
            end,
            mirror_sync_opts
          )
          |> Stream.run()

          for version <- map.deleted do
            store_delete(mirror, ["tarballs", "#{name}-#{version}.tar"])
          end

          {name, releases}
        end,
        mirror_sync_opts
      )

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

  def fetch_names(config) do
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
