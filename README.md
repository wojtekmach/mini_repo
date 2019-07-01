# NimbleHex

NimbleHex allows self-hosting of Hex packages.

Features:

* Pluggable storage. NimbleHex ships with local filesystem and S3 implementations
* Publishing packages via HTTP API
* Support for multiple repositories
* Mirroring

## Setup

Clone and install dependencies:

    git clone git@github.com:wojtekmach/nimble_hex.git
    cd nimble_hex
    mix deps.get

Start a development server:

    iex -S mix

By default, the development server is configured with two repositories:

1. `test_repo` is a custom repository
2. `hexpm_mirror` is a mirror of the official Hex.pm repository, configured to only fetch package
   "decimal".

Both repositories are configured to store files locally. See `config/config.exs` and `config/dev.exs` for more information.

Now, let's create a new package and publish it to our `test_repo` repository:

    mix new foo
    cd foo

Make following changes to `mix.exs`:

```elixir
  def project() do
    [
      # ...
      description: "Some description",
      package: package(),
      hex: hex()
    ]
  end

  defp package() do
    [
      licenses: ["Apache-2.0"],
      links: %{}
    ]
  end

  defp hex() do
    [
      api_url: "http://localhost:4000/api/repos/test_repo",
      api_key: "does-not-matter"
    ]
  end
```

Now publish the package:

    mix hex.publish package

Finally, in order to resolve the package, configure Hex to use the custom repository:

    cd /path/to/nimble_hex
    mix hex.repo add test_repo http://localhost:4000/repos/test_repo --public-key priv/test_repo_public.pem

And add it as a dependency from another Mix project:

```elixir
  defp deps() do
    {:foo, "~> 0.1", repo: "test_repo"}
  end
```

Since the development server includes a `hexpm_mirror` repo, let's try that too:

    HEX_MIRROR_URL=http://localhost:4000/repos/hexpm_mirror mix hex.package fetch decimal 1.8.0

See [`mix help hex.config`](https://hexdocs.pm/hex/Mix.Tasks.Hex.Config.html) for more information
about configuring your Hex installation.

## Deploying with releases

It's recommended to deploy NimbleHex with Elixir releases.

Our default releases setup has two additional assumptions:

* Configuration is provided via system environment variables
* Repositories are configured to use the `NimbleHex.Store.S3` storage engine

See `config/releases.exs` for more information.

Let's now assemble the release locally:

    $ mix release
    * assembling nimble_hex-0.1.0 on MIX_ENV=prod
    (...)

And start it:

    PORT=4000 \
    NIMBLE_HEX_URL=http://localhost:4000 \
    NIMBLE_HEX_S3_ACCESS_KEY_ID=xxx \
    NIMBLE_HEX_S3_SECRET_ACCESS_KEY=xxx \
    NIMBLE_HEX_S3_BUCKET=nimblehex \
    NIMBLE_HEX_S3_REGION=eu-central-1 \
    NIMBLE_HEX_PRIVATE_KEY=$(cat priv/test_repo_private.pem) \
    NIMBLE_HEX_PUBLIC_KEY=$(cat priv/test_repo_public.pem) \
    _build/prod/rel/nimble_hex/bin/nimble_hex start

By default, the files stored on S3 are not publicly accessible.
You can enable public access by setting following bucket policy in your
bucket's properties:

```json
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "AllowPublicRead",
            "Effect": "Allow",
            "Principal": {
                "AWS": "*"
            },
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::nimblehex/*"
        }
    ]
}
```

Since we're storing files on S3, we should use the publicly accessible URL as our repo:

    mix hex.repo add myrepo https://<bucket>.s3.<region>.amazonaws.com/repos/myrepo --public-key $NIMBLE_HEX_PUBLIC_KEY

## License

Copyright (c) 2019 Plataformatec

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
