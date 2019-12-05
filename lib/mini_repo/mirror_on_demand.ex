defmodule MiniRepo.MirrorOnDemand do
  @moduledoc """
  A mirror is a read-only repository that is kept in sync with another (upstream) repository.

  ## Fields

    * `:name` - mirror name

    * `:upstream_name` - the name of the repository we are mirroring

    * `:upstream_url` - the url of the repository we are mirroring

    * `:upstream_public_key` - the public key of the repository we are mirroring

    * `:store` - repository storage

    * `:sync_opts` - options used for syncing packages and releases concurrently
       (using `Task.Supervisor.async_stream_nolink/4`). Provided options will be merged with the
       default `[ordered: false]`.

    * `:sync_interval` - how often to check mirrored repository for changes in milliseconds.

    * `:only` - if set, it is an allowed list of packages to mirror. If not set, we mirror all
       available packages.

       When using `:only` option, you need to manually make sure that all of package's
       dependencies are included in the allowed list.

       Note, this mirror works by copying `/names` and `versions` resources from upstream.
       Thus, even though these resources may list a given package, if it's not in the allowed list it won't
       be stored in the mirror. An alternative mirror implementation could have `/names` and `/versions`
       resources only contain packages that the mirror actually has, but these resources would have
       to be signed with mirror's private key.

  ## Usage

  To set up a mirror, add it as any other repository:

      config :mini_repo,
        repositories: [
          a_mirror: [
            upstream_name: "some_mirror",
            upstream_url: "http://some_url",
            # ...
          ]
        ]

  """

  @enforce_keys [
    :name,
    :upstream_name,
    :upstream_url,
    :upstream_public_key,
    :sync_interval,
    :store
  ]
  defstruct [
    :name,
    :upstream_name,
    :upstream_url,
    :upstream_public_key,
    :sync_interval,
    :on_demand,
    :store,
    registry: %{},
    sync_opts: []
  ]
end
