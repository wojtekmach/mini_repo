# NimbleHex

NimbleHex allows self-hosting of Hex packages.

Features:

  * Pluggable storage. NimbleHex ships with following adapters:

      * Local filesystem

      * S3

  * Mirroring

  * Publishing packages via HTTP API

  * Hosting of multiple repositories and mirrors

    NimbleHex exposes following URLs for API and repository access:

      * http://some_url/api/<repo>

      * http://some_url/repos/<repo>

## Setup

Clone and install dependencies:

    git clone git@github.com:wojtekmach/nimble_hex.git
    cd nimble_hex
    mix deps.get

Start a development server:

    iex -S mix

By default, the development server is configured with two repositories:

  * `test_repo` is a custom repository

  * `hexpm_mirror` is a mirror of the official Hex.pm repository, configured to only fetch package
    `decimal`.

Both repositories are configured to store files locally. See [`config/dev.exs`](config/dev.exs) for more information.

Make sure to also read "Deployment with releases" section below releases" section below.

## Usage

Once you have the NimbleHex server running, here is how you can use it with Mix or Rebar3.

### Usage with Mix

Let's create a new package and publish it to our `test_repo` repository:

    $ mix new foo
    $ cd foo

Make following changes to that package's `mix.exs`:

```elixir
  def project() do
    [
      app: :foo,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Some description",
      package: package(),
      hex: hex(),
    ]
  end

  defp deps() do
    []
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

      # client requires an API key, but since NimbleHex does not
      # support authentication, you can put any key here
      api_key: "does-not-matter"
    ]
  end
```

Now publish the package:

    $ mix hex.publish package

Finally, let's use this package from another project.

First, configure Hex to use the custom repository:

    $ cd /path/to/nimble_hex
    $ mix hex.repo add test_repo http://localhost:4000/repos/test_repo --public-key priv/test_repo_public.pem

Now, create a new Mix project:

    $ mix new bar
    $ cd bar

And configure the dependency, note the `repo` configuration option.

```elixir
  defp deps() do
    [
      {:foo, "~> 0.1", repo: "test_repo"}
    ]
  end
```

Since the development server includes a `hexpm_mirror` repo, let's try that too:

    $ HEX_MIRROR_URL=http://localhost:4000/repos/hexpm_mirror mix hex.package fetch decimal 1.8.0

See [`mix help hex.config`](https://hexdocs.pm/hex/Mix.Tasks.Hex.Config.html) for more information
about configuring your Hex installation.

### Usage with Rebar3

Let's create a new package and publish it to our `test_repo` repository:

    $ rebar3 new lib baz
    $ cd baz

Now, let's configure Rebar3 to use our custom repo:

```erlang
%% ~/.config/rebar3/rebar.config
{plugins, [rebar3_hex]}.
{hex, [
  {repos, [
    #{
      name => <<"test_repo">>,

      %% client requires an API key, but since NimbleHex does not
      %% support authentication, you can put any key here
      api_key => <<"does-not-matter">>,

      api_url => <<"http://localhost:4000/api">>,
      api_repository => <<"test_repo">>
    }
  ]}
]}.
```

And publish the package specifying the repo:

    $ rebar3 hex publish -r test_repo

**TODO** Finally, let's use this package from another project:


### Deployment with releases

It's recommended to deploy NimbleHex with Elixir releases.

Let's now assemble the release locally:

    $ MIX_ENV=prod mix release
    * assembling nimble_hex-0.1.0 on MIX_ENV=prod
    (...)

And start it:

    PORT=4000 \
    NIMBLE_HEX_URL=http://localhost:4000 \
    _build/prod/rel/nimble_hex/bin/nimble_hex start

As you can see, some configuration can be set by adjusting system environment variables,
see [`config/releases.exs`](config/releases.exs)

Also, see [`mix help release`](https://hexdocs.pm/mix/Mix.Tasks.Release.html?) for general
information on Elixir releases.

## More information

See following modules documentation to learn more about given feature:

* [`NimbleHex.Store.Local`](lib/nimble_hex/store/local.ex)

* [`NimbleHex.Store.S3`](lib/nimble_hex/store/s3.ex)

* [`NimbleHex.Mirror`](lib/nimble_hex/mirror.ex)

## License

Copyright (c) 2019 Plataformatec

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
