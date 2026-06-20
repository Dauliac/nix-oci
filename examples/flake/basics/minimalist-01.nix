# Example: minimal container with a single package.
#
# This is the simplest possible container — just a package.
# All other examples build on this by adding options to the same
# `example-hello` container (the module system merges them).
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hello = {
            package = pkgs.hello;
          };
        };
      };
  };
}
