# Example: container with additional runtime dependencies.
#
# Adds extra packages beyond the main package into the container.
# Dependencies are included in the OCI image alongside the main binary.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hello = {
            dependencies = [
              pkgs.coreutils
            ];
          };
        };
      };
  };
}
