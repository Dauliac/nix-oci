# Example: Container with a custom image name
#
# Demonstrates overriding the default image name so the built OCI image
# is published under a different name than the container attribute key.
#
# Options used:
#   - oci.containers.<name>.name (override the output image name)
#   - oci.containers.<name>.package (Nix package to include as entrypoint)
#
# Usage:
#   nix build .#oci-minimalistWithName
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithName = {
            name = "hola";
            package = pkgs.hello;
          };
        };
      };
  };
}
