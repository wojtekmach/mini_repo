defmodule NimbleHex.Mirror do
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
    :only,
    :store
  ]
end
