import Config

## Example configuration below, set actual configuration in config/#{Mix.env()}.exs.
#
# config :nimble_hex,
#   port: 4001,
#   url: "http://localhost:4001"
#
# config :ex_aws,
#   access_key_id: System.fetch_env!("NIMBLE_HEX_S3_ACCESS_KEY_ID"),
#   secret_access_key: System.fetch_env!("NIMBLE_HEX_S3_SECRET_ACCESS_KEY"),
#   json_codec: Jason
#
# config :nimble_hex,
#   repositories: [
#     # Sample repository with local storage
#     #
#     # Configure repository:
#     #
#     #     mix hex.repo add repo1 http://localhost:4000/repos/repo1 --public-key public_key.pem
#     #
#     # Configure publishing:
#     #
#     #     mix hex.config api_url http://localhost:4000/api/repos/repo1
#     #
#     repo1: [
#       private_key: "...",
#       public_key: "...",
#       store: {NimbleHex.Store.Local, root: {:nimble_hex, "data"}}
#     ],
#     # Sample repository with S3 storage,
#     #
#     # Configure repository:
#     #
#     #     mix hex.repo add repo2 https://<bucket>.s3.<region>.amazonaws.com/repos/repo2 --public-key public_key.pem
#     #
#     # Remember to set bucket as public when appropriate, configure CDN in front etc.
#     #
#     # Configure publishing:
#     #
#     #     mix hex.config api_url http://localhost:4000/api/repos/repo2
#     #
#     repo2: [
#       private_key: "...",
#       public_key: "...",
#       store:
#         {NimbleHex.Store.S3,
#          bucket: System.fetch_env!("NIMBLE_HEX_S3_BUCKET"),
#          region: System.fetch_env!("NIMBLE_HEX_S3_REGION")}
#     ],
#     # A Mirror checks upstream repository with given frequency for changes and syncs them.
#     #
#     # Mirrors are read-only and must be configured with upstream URL and public key.
#     #
#     # The optional `:only` option configures an allowed packages list to fetch.
#     # When using `:only` option, you need to manually make sure that all of package's
#     # dependencies are included in the allowed list. This also means that even though
#     # mirror's resources like `/names` and `/versions` include a given package, if it's
#     # not in the allowed list the mirror will have neither `/packages/:name` resource nor
#     # `/tarballs/:package-:version.tar` tarball.
#
#     # To use the mirror, set `HEX_MIRROR_URL=https://<bucket>.s3.<region>.amazonaws.com/repos/hexpm_mirror`.
#     #
#     # Alternatively, you can add the mirror as a repository.
#     # When configuring repository with Hex clients, remember to use mirror's original repository
#     # name so that repository verification can work. For example, to mirror hex.pm do:
#     #
#     #     mix hex.repo add hexpm https://<bucket>.s3.<region>.amazonaws.com/repos/hexpm_mirror --public-key public_key.pem
#     #
#     hexpm_mirror: [
#       mirror_name: "hexpm",
#       mirror_url: "https://repo.hex.pm",
#       # get latest public key from https://hex.pm/docs/public_keys
#       public_key: """
#       -----BEGIN PUBLIC KEY-----
#       MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApqREcFDt5vV21JVe2QNB
#       Edvzk6w36aNFhVGWN5toNJRjRJ6m4hIuG4KaXtDWVLjnvct6MYMfqhC79HAGwyF+
#       IqR6Q6a5bbFSsImgBJwz1oadoVKD6ZNetAuCIK84cjMrEFRkELtEIPNHblCzUkkM
#       3rS9+DPlnfG8hBvGi6tvQIuZmXGCxF/73hU0/MyGhbmEjIKRtG6b0sJYKelRLTPW
#       XgK7s5pESgiwf2YC/2MGDXjAJfpfCd0RpLdvd4eRiXtVlE9qO9bND94E7PgQ/xqZ
#       J1i2xWFndWa6nfFnRxZmCStCOZWYYPlaxr+FZceFbpMwzTNs4g3d4tLNUcbKAIH4
#       0wIDAQAB
#       -----END PUBLIC KEY-----
#       # 5 minutes
#       sync_interval: 5 * 60 * 1000,
#       only: ~w(decimal),
#       store:
#         {NimbleHex.Store.S3,
#          bucket: System.fetch_env!("NIMBLE_HEX_S3_BUCKET"),
#          region: System.fetch_env!("NIMBLE_HEX_S3_REGION")}
#     ]
#   ]

import_config "#{Mix.env()}.exs"
