# Example: enable layer optimization.
#
# Optimizes OCI layer composition for better caching and smaller
# incremental pulls.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          example-hello = {
            optimizeLayers = true;
          };
        };
      };
  };
}
