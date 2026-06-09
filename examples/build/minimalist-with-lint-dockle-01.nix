# Example: Minimalist container with Dockle image linting
#
# Runs `dockle` against the built image to check CIS Docker Benchmarks
# and container best practices.
#
# Usage:
#   nix run .#oci-lint-dockle-minimalistWithLintDockle
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithLintDockle = {
            package = pkgs.hello;
            lint.dockle = {
              enabled = true;
              ignore = [
                # Nix-built images don't use HEALTHCHECK in Dockerfile
                "CIS-DI-0006"
              ];
            };
          };
        };
      };
  };
}
