defmodule MiniRepo.Utils do
  @moduledoc false

  def unpack_tarball(tarball) do
    with {:ok, result} <- :hex_tarball.unpack(tarball, :memory) do
      %{checksum: checksum, metadata: metadata} = result
      {:ok, {metadata["name"], build_release(metadata, checksum)}}
    end
  end

  defp build_release(metadata, checksum) do
    %{
      version: Map.fetch!(metadata, "version"),
      checksum: checksum,
      dependencies: build_dependencies(metadata)
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
