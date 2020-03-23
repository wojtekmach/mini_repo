defmodule MiniRepo.APIAuth do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    if !String.starts_with?(conn.request_path, "/api") do
      conn
    else
      case get_req_header(conn, "authorization") do
        [token] ->
          if Plug.Crypto.secure_compare(token, Application.fetch_env!(:mini_repo, :auth_token)) do
            conn
          else
            unauthorized(conn)
          end

        _ ->
          unauthorized(conn)
      end
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/vnd.hex+erlang")
    |> send_resp(401, :erlang.term_to_binary("unauthorized"))
    |> halt()
  end
end
