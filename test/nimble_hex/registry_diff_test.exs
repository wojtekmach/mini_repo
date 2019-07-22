defmodule NimbleHex.RegistryDiffTest do
  use ExUnit.Case, async: true
  import NimbleHex.RegistryDiff

  describe "diff/2" do
    test "empty diff" do
      assert diff(%{}, %{}) == %{packages: %{created: [], deleted: []}, releases: %{}}
    end

    test "created packages" do
      registry = %{}
      versions = %{"foo" => %{versions: ["1.0.0"], retired: []}}

      assert diff(registry, versions) == %{
               packages: %{created: ["foo"], deleted: []},
               releases: %{}
             }
    end

    test "deleted packages" do
      registry = %{"foo" => [%{version: "1.0.0"}]}
      versions = %{}

      assert diff(registry, versions) == %{
               packages: %{created: [], deleted: ["foo"]},
               releases: %{}
             }
    end

    test "empty releases diff" do
      registry = %{"foo" => [%{version: "1.0.0"}]}
      versions = %{"foo" => %{versions: ["1.0.0"], retired: []}}

      assert diff(registry, versions) == %{
               packages: %{created: [], deleted: []},
               releases: %{}
             }
    end

    test "created releases" do
      registry = %{"foo" => [%{version: "1.0.0"}]}
      versions = %{"foo" => %{versions: ["1.0.0", "1.1.0"], retired: []}}

      assert diff(registry, versions) == %{
               packages: %{created: [], deleted: []},
               releases: %{
                 "foo" => %{
                   created: ["1.1.0"],
                   deleted: [],
                   retired: [],
                   unretired: []
                 }
               }
             }
    end

    test "deleted releases" do
      registry = %{"foo" => [%{version: "1.0.0"}, %{version: "1.1.0"}]}
      versions = %{"foo" => %{versions: ["1.0.0"], retired: []}}

      assert diff(registry, versions) == %{
               packages: %{created: [], deleted: []},
               releases: %{
                 "foo" => %{
                   created: [],
                   deleted: ["1.1.0"],
                   retired: [],
                   unretired: []
                 }
               }
             }
    end

    test "empty retired diff" do
      registry = %{"foo" => [%{version: "1.0.0", retired: %{reason: "security"}}]}
      versions = %{"foo" => %{versions: ["1.0.0"], retired: [0]}}

      assert diff(registry, versions) == %{
               packages: %{created: [], deleted: []},
               releases: %{}
             }
    end

    test "retired releases" do
      registry = %{"foo" => [%{version: "1.0.0"}]}
      versions = %{"foo" => %{versions: ["1.0.0"], retired: [0]}}

      assert diff(registry, versions) == %{
               packages: %{created: [], deleted: []},
               releases: %{
                 "foo" => %{
                   created: [],
                   deleted: [],
                   retired: ["1.0.0"],
                   unretired: []
                 }
               }
             }
    end

    test "unretired releases" do
      registry = %{"foo" => [%{version: "1.0.0", retired: %{reason: "security"}}]}
      versions = %{"foo" => %{versions: ["1.0.0"], retired: []}}

      assert diff(registry, versions) == %{
               packages: %{created: [], deleted: []},
               releases: %{
                 "foo" => %{
                   created: [],
                   deleted: [],
                   retired: [],
                   unretired: ["1.0.0"]
                 }
               }
             }
    end
  end
end
