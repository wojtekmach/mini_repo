defmodule MiniRepo.APIAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    cond do
      !String.starts_with?(conn.request_path, "/api") ->
        conn

      get_req_header(conn, "authorization") == [Application.fetch_env!(:mini_repo, :auth_token)] ->
        conn

      true ->
        conn
        |> send_resp(401, "unauthorized")
        |> halt()
    end
  end
end
