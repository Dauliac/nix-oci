# Example: enable amicontained introspection probe.
#
# Runs `amicontained` inside the container (bind-mounted, not baked in)
# to report on runtime, capabilities, seccomp, and namespaces.
#
# Usage:
#   nix run .#oci-amicontained-example-hello
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hello = {
            test.amicontained.enabled = true;
          };
        };
      };
  };
}
