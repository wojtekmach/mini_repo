import Config

config :nimble_hex,
  port: 4000,
  url: "http://localhost:4000"

store = {NimbleHex.Store.Local, root: {:nimble_hex, "data"}}

config :nimble_hex,
  repositories: [
    test_repo: [
      private_key: File.read!(Path.expand("../priv/test_repo_private.pem", __DIR__)),
      public_key: File.read!(Path.expand("../priv/test_repo_public.pem", __DIR__)),
      store: store
    ],
    hexpm_mirror: [
      mirror_name: "hexpm",
      mirror_url: "https://repo.hex.pm",
      # 5min
      sync_interval: 5 * 60 * 1000,
      public_key: """
      -----BEGIN PUBLIC KEY-----
      MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApqREcFDt5vV21JVe2QNB
      Edvzk6w36aNFhVGWN5toNJRjRJ6m4hIuG4KaXtDWVLjnvct6MYMfqhC79HAGwyF+
      IqR6Q6a5bbFSsImgBJwz1oadoVKD6ZNetAuCIK84cjMrEFRkELtEIPNHblCzUkkM
      3rS9+DPlnfG8hBvGi6tvQIuZmXGCxF/73hU0/MyGhbmEjIKRtG6b0sJYKelRLTPW
      XgK7s5pESgiwf2YC/2MGDXjAJfpfCd0RpLdvd4eRiXtVlE9qO9bND94E7PgQ/xqZ
      J1i2xWFndWa6nfFnRxZmCStCOZWYYPlaxr+FZceFbpMwzTNs4g3d4tLNUcbKAIH4
      0wIDAQAB
      -----END PUBLIC KEY-----
      """,
      only: ~w(decimal),
      store: store
    ]
  ]
