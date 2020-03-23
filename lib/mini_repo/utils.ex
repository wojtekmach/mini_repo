defmodule MiniRepo.Utils do
  @moduledoc false

  def unpack_tarball(tarball) do
    with {:ok, result} <- :hex_tarball.unpack(tarball, :memory),
         :ok <- validate_metadata(result.metadata) do
      {:ok, {result.metadata["name"], build_release(result)}}
    end
  end

  # TODO: move metadata validations to hex_core
  defp validate_metadata(metadata) do
    with :ok <- validate_name(metadata) do
      validate_version(metadata)
    end
  end

  defp validate_name(metadata) do
    if metadata["name"] =~ ~r/^[a-z]\w*$/ do
      :ok
    else
      {:error, :invalid_name}
    end
  end

  defp validate_version(metadata) do
    case Version.parse(metadata["version"]) do
      {:ok, _} -> :ok
      :error -> {:error, :invalid_version}
    end
  end

  defp build_release(result) do
    %{
      version: Map.fetch!(result.metadata, "version"),
      inner_checksum: result.inner_checksum,
      outer_checksum: result.outer_checksum,
      dependencies: build_dependencies(result.metadata)
    }
  end

  defp build_dependencies(metadata) do
    for {package, map} <- Map.fetch!(metadata, "requirements") do
      %{
        package: package,
        requirement: map["requirement"]
      }
      |> maybe_put(:app, map["app"])
      |> maybe_put(:optional, map["optional"])
      |> maybe_put(:repository, map["repository"])
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  def generate_keys() do
    {:ok, private_key} = generate_rsa_key(2048, 65537)
    public_key = extract_public_key(private_key)
    {pem_encode(:RSAPrivateKey, private_key), pem_encode(:RSAPublicKey, public_key)}
  end

  require Record

  Record.defrecordp(
    :rsa_private_key,
    :RSAPrivateKey,
    Record.extract(:RSAPrivateKey, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  )

  Record.defrecordp(
    :rsa_public_key,
    :RSAPublicKey,
    Record.extract(:RSAPublicKey, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  )

  defp pem_encode(type, key) do
    :public_key.pem_encode([:public_key.pem_entry_encode(type, key)])
  end

  defp generate_rsa_key(keysize, e) do
    private_key = :public_key.generate_key({:rsa, keysize, e})
    {:ok, private_key}
  rescue
    FunctionClauseError ->
      {:error, :not_supported}
  end

  defp extract_public_key(rsa_private_key(modulus: m, publicExponent: e)) do
    rsa_public_key(modulus: m, publicExponent: e)
  end
end
