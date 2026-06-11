# Example: Minimalist container with amicontained introspection
#
# Runs `amicontained` inside the container (bind-mounted, not baked in)
# to report on runtime, capabilities, seccomp, and namespaces.
#
# Usage:
#   nix run .#oci-amicontained-minimalistWithAmicontained
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithAmicontained = {
            package = pkgs.hello;
            test.amicontained.enabled = true;
          };
        };
      };
  };
}
