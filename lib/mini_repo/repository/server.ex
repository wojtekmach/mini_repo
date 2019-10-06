defmodule MiniRepo.Repository.Server do
  @moduledoc false

  use Agent
  alias MiniRepo.RegistryBackup

  def start_link(options) do
    {repository, options} = Keyword.pop(options, :repository)
    Agent.start_link(fn -> RegistryBackup.load(repository) end, options)
  end

  def publish(pid, tarball) do
    with {:ok, {package_name, release}} <- MiniRepo.Utils.unpack_tarball(tarball) do
      Agent.update(pid, fn repository ->
        :ok =
          store_put(repository, tarball_path(repository, package_name, release.version), tarball)

        update_registry(repository, package_name, fn registry ->
          Map.update(registry, package_name, [release], &[release | &1])
        end)
      end)
    end
  end

  def revert(pid, package_name, version) do
    Agent.update(pid, fn repository ->
      update_registry(repository, package_name, fn registry ->
        case Map.fetch!(registry, package_name) do
          [%{version: ^version}] ->
            :ok = store_delete(repository, tarball_path(repository, package_name, version))
            Map.delete(registry, package_name)

          _ ->
            Map.update!(registry, package_name, fn releases ->
              Enum.reject(releases, &(&1.version == version))
            end)
        end
      end)
    end)
  end

  defp tarball_path(repository, package_name, version) do
    ["repos", repository.name, "tarballs", "#{package_name}-#{version}.tar"]
  end

  def retire(pid, package_name, version, params) do
    Agent.update(pid, fn repository ->
      update_registry(repository, package_name, fn registry ->
        Map.update!(registry, package_name, fn releases ->
          for release <- releases do
            if release.version == version do
              params = Map.update!(params, :reason, &retirement_reason/1)
              Map.put(release, :retired, params)
            else
              release
            end
          end
        end)
      end)
    end)
  end

  defp retirement_reason("other"), do: :RETIRED_OTHER
  defp retirement_reason("invalid"), do: :RETIRED_INVALID
  defp retirement_reason("security"), do: :RETIRED_SECURITY
  defp retirement_reason("deprecated"), do: :RETIRED_DEPRECATED
  defp retirement_reason("renamed"), do: :RETIRED_RENAMED

  def unretire(pid, package_name, version) do
    Agent.update(pid, fn repository ->
      update_registry(repository, package_name, fn registry ->
        Map.update!(registry, package_name, fn releases ->
          for release <- releases do
            if release.version == version do
              Map.delete(release, :retired)
            else
              release
            end
          end
        end)
      end)
    end)
  end

  def publish_docs(pid, package_name, version, docs_tarball) do
    Agent.update(pid, fn repository ->
      store_put(
        repository,
        ["repos", repository.name, "docs", "#{package_name}-#{version}.tar.gz"],
        docs_tarball
      )

      repository
    end)
  end

  defp update_registry(repository, package_name, fun) do
    repository = Map.update!(repository, :registry, fun)
    build_partial_registry(repository, package_name)
    RegistryBackup.save(repository)
    repository
  end

  # defp build_full_registry(repository, repo) do
  #   packages = Map.fetch!(repository.registry, repo)
  #   resources = MiniRepo.RegistryBuilder.build_full(repository, packages)

  #   for {name, content} <- resources do
  #     store_put(repository, ["repos", repo, name], content)
  #   end
  # end

  defp build_partial_registry(repository, package_name) do
    resources =
      MiniRepo.RegistryBuilder.build_partial(repository, repository.registry, package_name)

    for {name, content} <- resources do
      store_put(repository, ["repos", repository.name, name], content)
    end
  end

  defp store_put(repository, name, content) do
    options = []
    :ok = MiniRepo.Store.put(repository.store, name, content, options)
  end

  defp store_delete(repository, name) do
    MiniRepo.Store.delete(repository.store, name)
  end
end
