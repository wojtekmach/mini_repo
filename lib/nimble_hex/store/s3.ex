defmodule NimbleHex.Store.S3 do
  @moduledoc """
  S3 storage.

  Options:

    * `:bucket` - the S3 bucket
    * `:region` - the S3 region
  """

  @behaviour NimbleHex.Store

  alias ExAws.S3

  defstruct [:bucket, :region]

  @impl true
  def put(key, value, options, state) do
    key = Path.join(List.wrap(key))
    request = S3.put_object(state.bucket, key, value, options)

    with {:ok, _} <- ExAws.request(request, region: state.region) do
      :ok
    end
  end

  @impl true
  def fetch(key, options, state) do
    key = Path.join(List.wrap(key))
    request = S3.get_object(state.bucket, key, options)

    case ExAws.request(request, region: state.region) do
      {:ok, %{body: body}} ->
        {:ok, body}

      {:error, {:http_error, 404, _}} ->
        {:error, :not_found}

      other ->
        other
    end
  end

  @impl true
  def delete(key, options, state) do
    key = Path.join(List.wrap(key))
    request = S3.delete_object(state.bucket, key, options)

    with {:ok, _} <- ExAws.request(request, region: state.region) do
      :ok
    end
  end
end
