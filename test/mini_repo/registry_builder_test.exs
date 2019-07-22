defmodule MiniRepo.RegistryBuilderTest do
  use ExUnit.Case, async: true
  alias MiniRepo.{RegistryBuilder, Repository}

  setup do
    {private_key, public_key} = MiniRepo.Utils.generate_keys()

    repository = %Repository{
      name: "test",
      private_key: private_key,
      public_key: public_key,
      store: SomeStore
    }

    [repository: repository]
  end

  test "build_full", %{repository: repository} do
    registry = %{
      "foo" => [
        %{version: "1.0.0", checksum: "abcd"},
        %{
          version: "1.1.0",
          checksum: "efgh",
          retired: %{reason: :RETIRED_SECURITY, message: "CVE-2019-0000"}
        }
      ],
      "bar" => [
        %{
          version: "1.0.0",
          checksum: "ijkl",
          dependencies: [
            %{package: "foo", requirement: "~> 1.0"}
          ]
        }
      ]
    }

    %{
      "names" => signed_names,
      "versions" => signed_versions,
      "packages/foo" => signed_package_foo,
      "packages/bar" => signed_package_bar
    } = RegistryBuilder.build_full(repository, registry)

    assert RegistryBuilder.decode_names(repository, signed_names) ==
             {:ok, [%{name: "bar"}, %{name: "foo"}]}

    assert RegistryBuilder.decode_versions(repository, signed_versions) ==
             {:ok,
              [
                %{name: "bar", retired: [], versions: ["1.0.0"]},
                %{name: "foo", retired: [1], versions: ["1.0.0", "1.1.0"]}
              ]}

    assert RegistryBuilder.decode_package(repository, signed_package_foo, "foo") ==
             {:ok,
              [
                %{
                  version: "1.0.0",
                  checksum: "abcd",
                  dependencies: []
                },
                %{
                  version: "1.1.0",
                  checksum: "efgh",
                  dependencies: [],
                  retired: %{reason: :RETIRED_SECURITY, message: "CVE-2019-0000"}
                }
              ]}

    assert RegistryBuilder.decode_package(repository, signed_package_bar, "bar") ==
             {:ok,
              [
                %{
                  dependencies: [%{package: "foo", requirement: "~> 1.0"}],
                  version: "1.0.0",
                  checksum: "ijkl"
                }
              ]}
  end

  test "build_partial", %{repository: repository} do
    registry = %{
      "foo" => [
        %{version: "1.0.0", checksum: "abcd"},
        %{
          version: "1.1.0",
          checksum: "efgh",
          retired: %{reason: :RETIRED_SECURITY, message: "CVE-2019-0000"}
        }
      ],
      "bar" => [
        %{
          version: "1.0.0",
          checksum: "ijkl",
          dependencies: [
            %{package: "foo", requirement: "~> 1.0"}
          ]
        }
      ]
    }

    %{
      "names" => signed_names,
      "versions" => signed_versions,
      "packages/foo" => signed_package_foo
    } = RegistryBuilder.build_partial(repository, registry, "foo")

    assert {:ok, _} = RegistryBuilder.decode_names(repository, signed_names)
    assert {:ok, _} = RegistryBuilder.decode_versions(repository, signed_versions)
    assert {:ok, _} = RegistryBuilder.decode_package(repository, signed_package_foo, "foo")
  end
end
