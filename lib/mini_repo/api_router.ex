defmodule MiniRepo.APIRouter do
  @moduledoc false
  use Plug.Router
  require Logger

  plug Plug.Parsers,
    parsers: [MiniRepo.HexErlangParser],
    pass: ["*/*"]

  plug :match
  plug :dispatch, builder_opts()

  def call(conn, opts) do
    conn =
      Plug.Conn.put_private(conn, :mini_repo, %{
        url: opts[:url],
        repositories: opts[:repositories]
      })

    super(conn, opts)
  end

  post "/api/repos/:repo/publish" do
    {:ok, tarball, conn} = read_tarball(conn)
    repo = repo!(conn, repo)

    case MiniRepo.Repository.Server.publish(repo, tarball) do
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

    case MiniRepo.Repository.Server.revert(repo, name, version) do
      :ok -> send_resp(conn, 204, "")
      {:error, _} = error -> send_resp(conn, 400, inspect(error))
    end
  end

  post "/api/repos/:repo/packages/:name/releases/:version/retire" do
    repo = repo!(conn, repo)

    case MiniRepo.Repository.Server.retire(repo, name, version, conn.body_params) do
      :ok -> send_resp(conn, 201, "")
      {:error, _} = error -> send_resp(conn, 400, inspect(error))
    end
  end

  delete "/api/repos/:repo/packages/:name/releases/:version/retire" do
    repo = repo!(conn, repo)

    case MiniRepo.Repository.Server.unretire(repo, name, version) do
      :ok -> send_resp(conn, 201, "")
      {:error, _} = error -> send_resp(conn, 400, inspect(error))
    end
  end

  post "/api/repos/:repo/packages/:name/releases/:version/docs" do
    repo = repo!(conn, repo)
    {:ok, docs_tarball, conn} = read_tarball(conn)

    case MiniRepo.Repository.Server.publish_docs(repo, name, version, docs_tarball) do
      :ok -> send_resp(conn, 201, "")
      {:error, _} = error -> send_resp(conn, 400, inspect(error))
    end
  end

  get "/repos/hexpm_mirror/packages/:name" do
    if is_configured_on_demand?() do
      MiniRepo.Mirror.ServerOnDemand.fetch_if_not_exist(name)
    end
   
    path = Path.join(Application.app_dir(:mini_repo), "data/repos/hexpm_mirror/packages/#{name}")

    case File.exists?(path) do
      true -> send_file(conn, 200, path)
      false -> send_resp(conn, 404, "Package not found")
    end
  end

  get "/repos/hexpm_mirror/tarballs/:tarball" do
    name = 
    String.split(tarball, "-")
    |> Enum.at(0)

    if is_configured_on_demand?() do
      MiniRepo.Mirror.ServerOnDemand.fetch_if_not_exist(name)
    end

    path = Path.join(Application.app_dir(:mini_repo), "data/repos/hexpm_mirror/tarballs/#{tarball}")

    case File.exists?(path) do
      true -> send_file(conn, 200, path)
      false -> send_resp(conn, 404, "Package not found")
    end
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  defp repo!(conn, repo) do
    allowed_repos = conn.private.mini_repo.repositories

    if repo in allowed_repos do
      String.to_existing_atom(repo)
    else
      raise ArgumentError,
            "#{inspect(repo)} is not allowed, allowed repos: #{inspect(allowed_repos)}"
    end
  end

  def is_configured_on_demand?() do
    Application.get_all_env(:mini_repo)
    |> Keyword.fetch!(:repositories)
    |> Enum.filter(fn
      {:hexpm_mirror, x} -> Keyword.has_key?(x, :on_demand)
      {_, _} -> false
    end)
    |> Enum.empty?()
    |> Kernel.not()
  end

  defp read_tarball(conn, tarball \\ <<>>) do
    case Plug.Conn.read_body(conn) do
      {:more, partial, conn} ->
        read_tarball(conn, tarball <> partial)

      {:ok, body, conn} ->
        {:ok, tarball <> body, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
