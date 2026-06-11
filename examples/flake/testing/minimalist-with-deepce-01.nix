# Example: Minimalist container with DEEPCE escape detection
#
# Runs `deepce.sh` inside the container (bind-mounted with busybox,
# not baked in) to enumerate escape vectors and privilege escalation
# paths.
#
# Usage:
#   nix run .#oci-deepce-minimalistWithDeepce
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithDeepce = {
            package = pkgs.hello;
            test.deepce.enabled = true;
          };
        };
      };
  };
}
