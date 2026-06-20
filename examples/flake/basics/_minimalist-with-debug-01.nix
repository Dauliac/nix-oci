# Example: minimal container with a debug flavour
#
# The debug flavour inherits all parent config and adds extra packages.
# Produces two images: oci-minimalistWithDebug, oci-minimalistWithDebug-debug
{ ... }:
{
  config = {
    perSystem =
      {
        pkgs,
        config,
        ...
      }:
      {
        config.oci.containers = {
          minimalistWithDebug = {
            package = pkgs.kubectl;
            flavours.debug = {
              dependencies = with pkgs; [
                coreutils
                bash
                curl
              ];
            };
          };
        };
      };
  };
}
