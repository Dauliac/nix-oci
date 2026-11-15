# Build the full repository reference for a container
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  nix-lib.lib.oci.mkRepoRef = {
    type = lib.types.functionTo lib.types.str;
    description = "Build a container's repository reference (`<registry>/<name>` or `<name>`), lowercasing the repository path as the OCI distribution spec requires";
    file = "nix/modules/oci/lib/ociMkRepoRef.nix";
    fn =
      {
        registry,
        name,
      }:
      pure.mkRepoRef { inherit registry name; };
    tests = {
      "prefixes the registry when set" = {
        args = {
          registry = "ghcr.io/dauliac";
          name = "web";
        };
        expected = "ghcr.io/dauliac/web";
      };
      "lowercases the repository path" = {
        args = {
          registry = "ghcr.io/dauliac";
          name = "MyApp";
        };
        expected = "ghcr.io/dauliac/myapp";
      };
      "lowercases a bare name when no registry is set" = {
        args = {
          registry = null;
          name = "MyApp";
        };
        expected = "myapp";
      };
      "treats an empty registry as unset" = {
        args = {
          registry = "";
          name = "MyApp";
        };
        expected = "myapp";
      };
      "keeps the registry host verbatim" = {
        args = {
          registry = "Localhost:5000";
          name = "Web";
        };
        expected = "Localhost:5000/web";
      };
    };
  };
}
