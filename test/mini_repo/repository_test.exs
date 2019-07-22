defmodule MiniRepo.RepositoryTest do
  use ExUnit.Case, async: true
  alias MiniRepo.Repository

  test "inspect" do
    {private_key, public_key} = MiniRepo.Utils.generate_keys()

    repository = %Repository{
      name: "test",
      private_key: private_key,
      public_key: public_key,
      store: SomeStore
    }

    assert inspect(repository) ==
             "#MiniRepo.Repository<name: \"test\", public_key: #{inspect(public_key)}, registry: %{}, store: SomeStore, ...>"
  end
end
