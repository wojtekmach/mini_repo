defmodule NimbleHex.Router do
  @moduledoc false
  use Plug.Router

  plug Plug.Parsers,
    parsers: [NimbleHex.HexErlangParser],
    pass: ["*/*"]

  plug :match
  plug :dispatch, builder_opts()

  post "/api/repos/:repo/publish" do
    {:ok, tarball, conn} = Plug.Conn.read_body(conn, length: :infinity)
    repo = repo!(conn, repo)

    case NimbleHex.Repository.Server.publish(repo, tarball) do
      :ok ->
        body = %{"url" => opts[:url]}
        body = :erlang.term_to_binary(body)

        conn
        |> put_resp_content_type("application/vnd.hex+erlang")
        |> send_resp(200, body)

      {:error, _} = error ->
        send_resp(conn, 400, inspect(error))
    end
  end

  delete "/api/repos/:repo/packages/:name/releases/:version" do
    repo = repo!(conn, repo)

    case NimbleHex.Repository.Server.revert(repo, name, version) do
      :ok -> send_resp(conn, 204, "")
      {:error, _} = error -> send_resp(conn, 400, inspect(error))
    end
  end

  post "/api/repos/:repo/packages/:name/releases/:version/retire" do
    repo = repo!(conn, repo)

    case NimbleHex.Repository.Server.retire(repo, name, version, conn.body_params) do
      :ok -> send_resp(conn, 201, "")
      {:error, _} = error -> send_resp(conn, 400, inspect(error))
    end
  end

  delete "/api/repos/:repo/packages/:name/releases/:version/retire" do
    repo = repo!(conn, repo)

    case NimbleHex.Repository.Server.unretire(repo, name, version) do
      :ok -> send_resp(conn, 201, "")
      {:error, _} = error -> send_resp(conn, 400, inspect(error))
    end
  end

  post "/api/repos/:repo/packages/:name/releases/:version/docs" do
    {:ok, docs_tarball, conn} = Plug.Conn.read_body(conn, length: :infinity)
    repo = String.to_atom(repo)

    case NimbleHex.Repository.Server.publish_docs(repo, name, version, docs_tarball) do
      :ok -> send_resp(conn, 201, "")
      {:error, _} = error -> send_resp(conn, 400, inspect(error))
    end
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  # TODO: pass allowed repos to router and only allow them here
  defp repo!(_conn, repo) do
    String.to_atom(repo)
  end
end
