defmodule MiniRepo.Store do
  @callback put(path :: Path.t(), value :: binary, options :: keyword, state :: any) ::
              :ok | {:error, term}

  @callback fetch(path :: Path.t(), options :: keyword, state :: any) ::
              {:ok, binary} | {:error, term}

  @callback delete(path :: Path.t(), options :: keyword, state :: any) ::
              :ok | {:error, term}

  def put({mod, state}, path, value, options \\ []) do
    path = validate_path!(path)
    state = struct!(mod, state)
    mod.put(path, value, options, state)
  end

  def fetch({mod, state}, path, options \\ []) do
    path = validate_path!(path)
    state = struct!(mod, state)
    mod.fetch(path, options, state)
  end

  def delete({mod, state}, path, options \\ []) do
    path = validate_path!(path)
    state = struct!(mod, state)
    mod.delete(path, options, state)
  end

  defp validate_path!(path) do
    path = path |> List.wrap() |> List.flatten()

    if invalid_path?(path) do
      raise ArgumentError, "invalid path: #{inspect(path)}"
    end

    path
  end

  # https://github.com/elixir-plug/plug/blob/v1.8.3/lib/plug/static.ex#L396:L402
  defp invalid_path?(list) do
    invalid_path?(list, :binary.compile_pattern(["/", "\\", ":", "\0"]))
  end

  defp invalid_path?([h | _], _match) when h in [".", "..", ""], do: true
  defp invalid_path?([h | t], match), do: String.contains?(h, match) or invalid_path?(t)
  defp invalid_path?([], _match), do: false
end
