defmodule MiniRepo.Endpoint do
  @moduledoc false

  use Plug.Builder

  plug Plug.Logger

  plug Plug.Static,
    at: "/repos",
    from: {:mini_repo, "data/repos"}

  plug MiniRepo.Router, builder_opts()
end
