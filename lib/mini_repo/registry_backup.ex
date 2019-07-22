defmodule MiniRepo.RegistryBackup do
  @moduledoc false

  @manifest_vsn 1

  def save(repository) do
    contents = %{
      manifest_vsn: @manifest_vsn,
      registry: repository.registry
    }

    store_put(repository, backup_path(repository), :erlang.term_to_binary(contents))
  end

  def load(repository) do
    registry =
      case store_fetch(repository, backup_path(repository)) do
        {:ok, contents} ->
          manifest_vsn = @manifest_vsn

          %{manifest_vsn: ^manifest_vsn, registry: registry} = :erlang.binary_to_term(contents)

          registry

        {:error, :not_found} ->
          %{}
      end

    %{repository | registry: registry}
  end

  defp backup_path(repository) do
    repository.name <> ".bin"
  end

  defp store_put(repository, name, content) do
    options = []
    :ok = MiniRepo.Store.put(repository.store, name, content, options)
  end

  defp store_fetch(repository, name) do
    MiniRepo.Store.fetch(repository.store, name)
  end
end
