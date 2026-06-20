# Example: enable linPEAS privilege escalation audit probe.
#
# Runs `linpeas` inside the container (bind-mounted with busybox)
# to audit for privilege escalation vectors.
#
# Usage:
#   nix run .#oci-linpeas-example-hello
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hello = {
            test.linpeas.enabled = true;
          };
        };
      };
  };
}
