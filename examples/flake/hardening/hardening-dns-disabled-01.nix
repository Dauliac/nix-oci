# Example: disable DNS resolution in the container.
#
# Removes DNS-related files and restricts nsswitch.conf to files-only
# resolution. Useful for containers that should never resolve hostnames.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hardened = {
            hardening.disableDns = true;
          };
        };
      };
  };
}
