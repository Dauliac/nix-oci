# Example: Testing with dgoss
#
# Demonstrates enabling dgoss (Docker wrapper for goss) to run
# server validation tests against the built container image.
#
# Options used:
#   - oci.containers.<name>.package (Nix package to include as entrypoint)
#   - oci.containers.<name>.test.dgoss.enabled (enable dgoss testing)
#
# Usage:
#   nix build .#oci-minimalistWithDgoss
{ ... }:
{
  config = {
    perSystem =
      {
        pkgs,
        config,
        ...
      }:
      {
        config.oci.containers = {
          minimalistWithDgoss = {
            package = pkgs.kubectl;
            test.dgoss.enabled = true;
          };
        };
      };
  };
}
