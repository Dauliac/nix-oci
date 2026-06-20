# Example: enable DEEPCE container escape detection probe.
#
# Runs `deepce` inside the container (bind-mounted with busybox)
# to detect container escape vectors.
#
# Usage:
#   nix run .#oci-deepce-example-hello
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hello = {
            test.deepce.enabled = true;
          };
        };
      };
  };
}
