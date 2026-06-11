# Example: Minimalist container with linPEAS privilege escalation audit
#
# Runs `linpeas.sh` inside the container (bind-mounted with busybox,
# not baked in) to enumerate privilege escalation vectors: SUID
# binaries, writable paths, capabilities, kernel exploits, etc.
#
# Usage:
#   nix run .#oci-linpeas-minimalistWithLinpeas
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithLinpeas = {
            package = pkgs.hello;
            test.linpeas.enabled = true;
          };
        };
      };
  };
}
