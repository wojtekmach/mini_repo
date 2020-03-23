defmodule MiniRepo.ApplicationTest do
  use ExUnit.Case

  setup do
    File.rm_rf!("tmp")
    File.rm_rf!(Path.join(Application.app_dir(:mini_repo), "data"))
    Application.ensure_all_started(:mini_repo)
    :ok
  end

  test "via hex_core" do
    # TODO: change test so that mirror is not started?

    [test_repo: test_repo, test_repo_mirror: _] =
      Application.fetch_env!(:mini_repo, :repositories)

    config = %{
      :hex_core.default_config()
      | repo_name: "test_repo",
        repo_url: "http://localhost:4001/repos/test_repo",
        repo_public_key: test_repo[:public_key],
        # for publishing
        api_key: "secret",
        api_url: "http://localhost:4001/api/repos/test_repo"
    }

    {:ok, {404, _, _}} = :hex_repo.get_names(config)

    {:ok, {400, _, {:error, {:tarball, :eof}}}} = :hex_api_release.publish(config, "bad")

    metadata = %{"name" => "foo", "version" => "1.0.0", "requirements" => []}
    files = [{'lib/foo.ex', "defmodule Foo do; end"}]
    {:ok, result} = :hex_tarball.create(metadata, files)
    {:ok, {200, _, %{"url" => url}}} = :hex_api_release.publish(config, result.tarball)
    assert url == "http://localhost:4001"

    bad_auth_config = %{config | api_key: "bad"}
    {:ok, {401, _, "unauthorized"}} = :hex_api_release.publish(bad_auth_config, result.tarball)

    {:ok, {200, _, packages}} = :hex_repo.get_names(config)
    assert packages == [%{name: "foo"}]

    {:ok, {200, _, packages}} = :hex_repo.get_versions(config)
    assert packages == [%{name: "foo", retired: [], versions: ["1.0.0"]}]

    {:ok, {200, _, [release]}} = :hex_repo.get_package(config, "foo")
    assert release.inner_checksum == result.inner_checksum
    assert release.outer_checksum == result.outer_checksum

    assert {:ok, {200, _, tarball}} = :hex_repo.get_tarball(config, "foo", "1.0.0")
    assert tarball == result.tarball

    {:ok, {201, _, _}} =
      :hex_api_release.retire(config, "foo", "1.0.0", %{
        "reason" => "security",
        "message" => "CVE-2019-0000"
      })

    {:ok, {200, _, packages}} = :hex_repo.get_versions(config)
    assert packages == [%{name: "foo", retired: [0], versions: ["1.0.0"]}]

    {:ok, {200, _, [release]}} = :hex_repo.get_package(config, "foo")
    assert release.retired == %{message: "CVE-2019-0000", reason: :RETIRED_SECURITY}

    {:ok, {201, _, _}} = :hex_api_release.unretire(config, "foo", "1.0.0")
    {:ok, {200, _, packages}} = :hex_repo.get_versions(config)
    assert packages == [%{name: "foo", retired: [], versions: ["1.0.0"]}]

    # restart application, load registry from backup
    Application.stop(:mini_repo)
    Application.start(:mini_repo)

    {:ok, {200, _, packages}} = :hex_repo.get_names(config)
    assert packages == [%{name: "foo"}]

    assert {:ok, {201, _, _}} = publish_docs(config, "foo", "1.0.0", {'text/plain', "foo"})
    assert {:ok, {200, _, "foo"}} = get_docs(config, "foo", "1.0.0")

    {:ok, {204, _, _}} = :hex_api_release.delete(config, "foo", "1.0.0")

    {:ok, {200, _, packages}} = :hex_repo.get_names(config)
    assert packages == []
  after
    Application.stop(:mini_repo)
  end

  test "mirror" do
    [test_repo: test_repo, test_repo_mirror: _] =
      Application.fetch_env!(:mini_repo, :repositories)

    config = %{
      :hex_core.default_config()
      | repo_name: "test_repo",
        repo_url: "http://localhost:4001/repos/test_repo",
        repo_public_key: test_repo[:public_key],
        # for publishing
        api_key: "secret",
        api_url: "http://localhost:4001/api/repos/test_repo"
    }

    mirror_config = %{
      :hex_core.default_config()
      | repo_name: "test_repo",
        repo_url: "http://localhost:4001/repos/test_repo_mirror",
        repo_public_key: test_repo[:public_key]
    }

    {:ok, {404, _, _}} = :hex_repo.get_names(config)
    {:ok, {404, _, _}} = :hex_repo.get_names(mirror_config)

    metadata = %{"name" => "foo", "version" => "1.0.0", "requirements" => []}
    files = [{'lib/foo.ex', "defmodule Foo do; end"}]
    {:ok, %{tarball: tarball}} = :hex_tarball.create(metadata, files)
    {:ok, {200, _, _}} = :hex_api_release.publish(config, tarball)

    {:ok, {200, _, packages}} = :hex_repo.get_names(config)
    assert packages == [%{name: "foo"}]

    Process.sleep(500)
    {:ok, {200, _, packages}} = :hex_repo.get_names(mirror_config)
    assert packages == [%{name: "foo"}]
    {:ok, {200, _, _}} = :hex_repo.get_tarball(mirror_config, "foo", "1.0.0")

    metadata = %{"name" => "foo", "version" => "1.1.0", "requirements" => []}
    files = [{'lib/foo.ex', "defmodule Foo do; end"}]
    {:ok, %{tarball: tarball}} = :hex_tarball.create(metadata, files)
    {:ok, {200, _, _}} = :hex_api_release.publish(config, tarball)

    Process.sleep(500)
    {:ok, {200, _, packages}} = :hex_repo.get_versions(mirror_config)
    assert packages == [%{name: "foo", retired: [], versions: ["1.0.0", "1.1.0"]}]
    {:ok, {200, _, _}} = :hex_repo.get_tarball(mirror_config, "foo", "1.1.0")
  after
    Application.stop(:mini_repo)
  end

  test "via hex" do
    [test_repo: test_repo, test_repo_mirror: _] =
      Application.fetch_env!(:mini_repo, :repositories)

    foo_path = Path.join(["tmp", "foo"])
    File.mkdir_p!(foo_path)

    File.write!(Path.join([foo_path, "mix.exs"]), """
    defmodule Foo.MixProject do
      use Mix.Project

      def project() do
        [
          app: :foo,
          version: "1.0.0",
          description: "Foo",
          package: [
            licenses: ["Apache-2.0"],
            links: %{},
            repo: "test_repo"
          ],
          hex: [
            api_url: "http://localhost:4001/api/repos/test_repo",
            api_key: "secret"
          ]
        ]
      end
    end
    """)

    File.cd!(foo_path, fn ->
      {_, 0} = System.cmd("mix", ~w(hex.build))
      {out, 0} = System.cmd("mix", ~w(hex.publish package --yes))
      # TODO: maybe update hex to display different repo name here
      # assert out =~ "Publishing package to **public** repository hexpm"
      assert out =~ "Package published to http://localhost:4001"
    end)

    bar_path = Path.join(["tmp", "bar"])
    File.mkdir_p!(bar_path)

    File.write!(Path.join([bar_path, "mix.exs"]), """
    defmodule Bar.MixProject do
      use Mix.Project

      def project() do
        [
          app: :bar,
          version: "1.0.0",
          description: "Bar",
          package: [
            licenses: ["Apache-2.0"],
            links: %{},
            repo: "test_repo"
          ],
          hex: [
            api_url: "http://localhost:4001/api/repos/test_repo",
            api_key: "secret"
          ],
          deps: [
            {:foo, "~> 1.0", repo: "test_repo"}
          ]
        ]
      end
    end
    """)

    File.cd!(bar_path, fn ->
      File.write!("public_key.pem", test_repo[:public_key])

      env = %{
        "HEX_HOME" => File.cwd!()
      }

      {_out, 0} =
        System.cmd(
          "mix",
          ~w(hex.repo add test_repo http://localhost:4001/repos/test_repo --public-key public_key.pem),
          env: env
        )

      {_, 0} = System.cmd("mix", ~w(deps.get), env: env)
      {out, 0} = System.cmd("mix", ~w(deps), env: env)
      assert out =~ "* foo (Hex package) (mix)\n  locked at 1.0.0 (test_repo/foo)"
    end)

    File.cd!(foo_path, fn ->
      {out, 0} = System.cmd("mix", ~w(hex.retire foo 1.0.0 security --message "CVE-2019-0000"))
      assert out =~ "foo 1.0.0 has been retired"
    end)
  after
    Application.stop(:mini_repo)
  end

  # TODO: move to hex_core
  defp get_docs(config, name, version) do
    url = repo_url(config, "/docs/#{name}-#{version}.tar.gz")
    :hex_http.request(config, :get, url, %{}, :undefined)
  end

  # TODO: move to hex_core
  defp publish_docs(config, name, version, body) do
    url = api_url(config, "/packages/#{name}/releases/#{version}/docs")
    headers = %{"authorization" => config.api_key}
    :hex_http.request(config, :post, url, headers, body)
  end

  defp repo_url(config, path) do
    config.repo_url <> path
  end

  defp api_url(config, path) do
    config.api_url <> path
  end
end
