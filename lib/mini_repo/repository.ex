defmodule MiniRepo.Repository do
  @moduledoc false

  @derive {Inspect, only: [:name, :public_key, :store, :registry]}
  @enforce_keys [:name, :public_key, :private_key, :store]
  defstruct [:name, :public_key, :private_key, :store, registry: %{}, extract_docs: false]
end
