defmodule NimbleHex.RegistryBuilder do
  def build_full(repository, registry) do
    resources = %{
      "names" => build_names(repository, registry),
      "versions" => build_versions(repository, registry)
    }

    for {name, releases} <- registry, into: resources do
      {"packages/#{name}", build_package(repository, name, releases)}
    end
  end

  def build_partial(repository, registry, name) do
    resources = %{
      "names" => build_names(repository, registry),
      "versions" => build_versions(repository, registry)
    }

    case Map.fetch(registry, name) do
      {:ok, releases} ->
        Map.put(resources, "packages/#{name}", build_package(repository, name, releases))

      # release is being reverted
      :error ->
        resources
    end
  end

  def build_names(repository, registry) do
    packages = for {name, _releases} <- registry, do: %{name: name}
    protobuf = :hex_registry.encode_names(%{repository: repository.name, packages: packages})
    sign_and_gzip(repository, protobuf)
  end

  def decode_names(repository, signed) do
    {:ok, protobuf} = gunzip_signed(repository, signed)
    :hex_registry.decode_names(protobuf, repository.name)
  end

  def build_versions(repository, registry) do
    packages =
      for {name, releases} <- Enum.sort_by(registry, &elem(&1, 0)) do
        versions =
          releases |> Enum.map(& &1.version) |> Enum.sort(&(Version.compare(&1, &2) == :lt))

        package = %{name: name, versions: versions}
        Map.put(package, :retired, retired_index(releases))
      end

    protobuf = :hex_registry.encode_versions(%{repository: repository.name, packages: packages})
    sign_and_gzip(repository, protobuf)
  end

  defp retired_index(releases) do
    for {release, index} <- Enum.with_index(releases),
        match?(%{retired: %{reason: _}}, release) do
      index
    end
  end

  def decode_versions(repository, signed) do
    {:ok, protobuf} = gunzip_signed(repository, signed)
    :hex_registry.decode_versions(protobuf, repository.name)
  end

  def build_package(repository, name, releases) do
    protobuf =
      :hex_registry.encode_package(%{repository: repository.name, name: name, releases: releases})

    sign_and_gzip(repository, protobuf)
  end

  def decode_package(repository, signed, name) do
    {:ok, protobuf} = gunzip_signed(repository, signed)
    :hex_registry.decode_package(protobuf, repository.name, name)
  end

  defp sign_and_gzip(repository, protobuf) do
    protobuf
    |> :hex_registry.sign_protobuf(repository.private_key)
    |> :zlib.gzip()
  end

  defp gunzip_signed(repository, signed) do
    signed
    |> :zlib.gunzip()
    |> :hex_registry.decode_and_verify_signed(repository.public_key)
  end
end
