defmodule NimbleHex.Endpoint do
  @moduledoc false

  use Plug.Builder

  plug Plug.Logger

  plug Plug.Static,
    at: "/repos",
    from: {:nimble_hex, "data/repos"}

  plug NimbleHex.Router, builder_opts()
end
