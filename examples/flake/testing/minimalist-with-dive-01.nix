# Example: enable Dive image efficiency analysis.
#
# Runs `dive` on the built image to check layer efficiency
# and wasted space.
#
# Usage:
#   nix run .#oci-dive-example-hello
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hello = {
            test.dive.enabled = true;
          };
        };
      };
  };
}
