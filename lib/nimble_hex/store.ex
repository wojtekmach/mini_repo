defmodule NimbleHex.Store do
  @callback put(path :: Path.t(), value :: binary, options :: keyword, state :: any) ::
              :ok | {:error, term}

  @callback fetch(path :: Path.t(), options :: keyword, state :: any) ::
              {:ok, binary} | {:error, term}

  @callback delete(path :: Path.t(), options :: keyword, state :: any) ::
              :ok | {:error, term}

  def put({mod, state}, path, value, options \\ []) do
    state = struct!(mod, state)
    mod.put(path, value, options, state)
  end

  def fetch({mod, state}, path, options \\ []) do
    state = struct!(mod, state)
    mod.fetch(path, options, state)
  end

  def delete({mod, state}, path, options \\ []) do
    state = struct!(mod, state)
    mod.delete(path, options, state)
  end
end
