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
        body = :erlang.term_to_binary(error)

        conn
        |> put_resp_content_type("application/vnd.hex+erlang")
        |> send_resp(400, body)
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
      MiniRepo.Mirror.ServerOnDemand.fetch_package_if_not_exist(name)
    end

    with {:ok, data_path} <- get_data_dir(:hexpm_mirror),
         package_path <-
           Path.join(
             Application.app_dir(:mini_repo),
             "#{data_path}/repos/hexpm_mirror/packages/#{name}"
           ),
         true <- File.exists?(package_path) do
      send_file(conn, 200, package_path)
    else
      _ ->
        send_resp(conn, 404, "not found")
    end
  end

  get "/repos/hexpm_mirror/tarballs/:tarball" do
    tb =
      String.split(tarball, "-")

      name = Enum.at(tb, 0)
      version = 
      Enum.at(tb, 1)
      |> String.replace(".tar", "")

    if is_configured_on_demand?() do
      MiniRepo.Mirror.ServerOnDemand.fetch_tarball_if_not_exist(name, version)
    end

    with {:ok, data_path} <- get_data_dir(:hexpm_mirror),
         tarbal_path <-
           Path.join(
             Application.app_dir(:mini_repo),
             "#{data_path}/repos/hexpm_mirror/tarballs/#{tarball}"
           ),
         true <- File.exists?(tarbal_path) do
      send_file(conn, 200, tarbal_path)
    else
      _ ->
        send_resp(conn, 404, "not found")
    end
  end

  get "/repos/:repo/packages/:name" do
    with {:ok, data_path} <- get_data_dir(String.to_atom(repo)),
         package_path <-
           Path.join(
             Application.app_dir(:mini_repo),
             "#{data_path}/repos/#{repo}/packages/#{name}"
           )
          do
      file = File.exists?(package_path)
      send_file(conn, 200, package_path)
    else
      e ->
        send_resp(conn, 404, "name: #{name}, repo: #{repo} not found")
    end
  end

  get "/repos/:repo/tarballs/:tarball" do
    with {:ok, data_path} <- get_data_dir(String.to_atom(repo)),
         tarbal_path <-
           Path.join(
             Application.app_dir(:mini_repo),
             "#{data_path}/repos/#{repo}/tarballs/#{tarball}"
           ),
         true <- File.exists?(tarbal_path) do
      send_file(conn, 200, tarbal_path)
    else
      _ ->
        send_resp(conn, 404, "repo: #{repo}, tarbal: #{tarball} not found")
    end
  end

  get "/repos/:repo/names/" do
    with {:ok, data_path} <- get_data_dir(String.to_atom(repo)),
         names_path <-
           Path.join(
             Application.app_dir(:mini_repo),
             "#{data_path}/repos/#{repo}/names/"
           ),
         true <- File.exists?(names_path) do
      send_file(conn, 200, names_path)
    else
      _ ->
        send_resp(conn, 404, "not found")
    end
  end

  get "/repos/:repo/versions/" do
    with {:ok, data_path} <- get_data_dir(String.to_atom(repo)),
         versions_path <-
           Path.join(
             Application.app_dir(:mini_repo),
             "#{data_path}/repos/#{repo}/versions/"
           ),
         true <- File.exists?(versions_path) do
      send_file(conn, 200, versions_path)
    else
      _ ->
        send_resp(conn, 404, "not found")
    end
  end

  get "/repos/:repo/docs/:tarball" do
    with {:ok, data_path} <- get_data_dir(String.to_atom(repo)),
         docs_path <-
           Path.join(
             Application.app_dir(:mini_repo),
             "#{data_path}/repos/#{repo}/docs/#{tarball}"
           ),
         true <- File.exists?(docs_path) do
      send_file(conn, 200, docs_path)
    else
      _ ->
        send_resp(conn, 404, "not found")
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

  def get_data_dir(repo) do
    repo =
      Application.get_env(:mini_repo, :repositories)
      |> Enum.filter(fn {key, _} -> key == repo end)

    case repo do
      [] ->
        {:error, "Repo not found"}

      [{_key, opts}] ->
        {_, [root: {_, dir}]} = opts[:store]
        {:ok, dir}

      _ ->
        {:error, "Duplicate repos defined"}
    end
  end

  defp is_configured_on_demand?() do
    Application.get_env(:mini_repo, :repositories)
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
