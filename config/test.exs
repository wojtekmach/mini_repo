import Config

config :nimble_hex,
  port: 4001,
  url: "http://localhost:4001"

store = {NimbleHex.Store.Local, root: {:nimble_hex, "data"}}

config :nimble_hex,
  repositories: [
    test_repo: [
      private_key: File.read!(Path.expand("../priv/test_repo_private.pem", __DIR__)),
      public_key: File.read!(Path.expand("../priv/test_repo_public.pem", __DIR__)),
      store: store
    ],
    test_repo_mirror: [
      mirror_name: "test_repo",
      mirror_url: "http://localhost:4001/repos/test_repo",
      # 100ms
      sync_interval: 100,
      public_key: File.read!(Path.expand("../priv/test_repo_public.pem", __DIR__)),
      store: store
    ]
  ]
