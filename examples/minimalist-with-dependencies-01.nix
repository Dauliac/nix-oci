{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          minimalistWithDependencies = {
            package = pkgs.kubectl;
            dependencies = [
              pkgs.bash
              pkgs.kubectl-cnpg
            ];
          };
        };
      };
  };
}
