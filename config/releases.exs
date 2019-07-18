import Config

config :nimble_hex,
  port: String.to_integer(System.get_env("PORT", "4000")),
  url: System.get_env("NIMBLE_HEX_URL", "http://localhost:4000")

repo_name = String.to_atom(System.get_env("NIMBLE_HEX_REPO_NAME", "test_repo"))

private_key =
  System.get_env("NIMBLE_HEX_PRIVATE_KEY") ||
    File.read!(Path.join([:code.priv_dir(:nimble_hex), "test_repo_private.pem"]))

public_key =
  System.get_env("NIMBLE_HEX_PUBLIC_KEY") ||
    File.read!(Path.join([:code.priv_dir(:nimble_hex), "test_repo_public.pem"]))

store = {NimbleHex.Store.Local, root: {:nimble_hex, "data"}}

config :nimble_hex,
  repositories: [
    "#{repo_name}": [
      private_key: private_key,
      public_key: public_key,
      store: store
    ],
    hexpm_mirror: [
      store: store,
      upstream_name: "hexpm",
      upstream_url: "https://repo.hex.pm",

      # https://hex.pm/docs/public_keys
      upstream_public_key: """
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

      # only mirror following packages
      only: ~w(decimal),

      # 5min
      sync_interval: 5 * 60 * 1000
    ]
  ]
