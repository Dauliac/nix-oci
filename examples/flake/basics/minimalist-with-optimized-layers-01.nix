{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithOptimizedLayers = {
            package = pkgs.kubectl;
            dependencies = [
              pkgs.bash
              pkgs.kubectl-cnpg
            ];
            optimizeLayers = true;
          };
        };
      };
  };
}
