# Example: enable Dockle image linting.
#
# Runs `dockle` against the built image to check CIS Docker Benchmarks
# and container best practices.
#
# Usage:
#   nix run .#oci-lint-dockle-example-hello
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hello = {
            lint.dockle.enabled = true;
          };
        };
      };
  };
}
