defmodule NimbleHex.Mirror do
  @enforce_keys [:name, :mirror_name, :mirror_url, :public_key, :sync_interval, :store]
  defstruct [:name, :mirror_name, :mirror_url, :public_key, :sync_interval, :only, :store]
end
