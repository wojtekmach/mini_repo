import Config

config :mini_repo,
  port: 4001,
  url: "http://localhost:4001"

store = {MiniRepo.Store.Local, root: {:mini_repo, "data"}}

config :mini_repo,
  auth_token: "secret",
  repositories: [
    test_repo: [
      store: store,
      private_key: File.read!(Path.expand("../priv/test_repo_private.pem", __DIR__)),
      public_key: File.read!(Path.expand("../priv/test_repo_public.pem", __DIR__))
    ],
    test_repo_mirror: [
      store: store,
      upstream_name: "test_repo",
      upstream_url: "http://localhost:4001/repos/test_repo",
      upstream_public_key: File.read!(Path.expand("../priv/test_repo_public.pem", __DIR__)),
      # 100ms
      sync_interval: 100
    ]
  ]
