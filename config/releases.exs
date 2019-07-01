import Config

config :nimble_hex,
  port: String.to_integer(System.fetch_env!("PORT")),
  url: System.fetch_env!("NIMBLE_HEX_URL")

config :ex_aws,
  access_key_id: System.fetch_env!("NIMBLE_HEX_S3_ACCESS_KEY_ID"),
  secret_access_key: System.fetch_env!("NIMBLE_HEX_S3_SECRET_ACCESS_KEY"),
  json_codec: Jason

store =
  {NimbleHex.Store.S3,
   bucket: System.fetch_env!("NIMBLE_HEX_S3_BUCKET"),
   region: System.fetch_env!("NIMBLE_HEX_S3_REGION")}

config :nimble_hex,
  repositories: [
    myrepo: [
      private_key: System.fetch_env!("NIMBLE_HEX_PRIVATE_KEY"),
      public_key: System.fetch_env!("NIMBLE_HEX_PUBLIC_KEY"),
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
      store: store,
      only: ~w(decimal)
    ]
  ]
