{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          withRootUserAndPackage = {
            package = pkgs.bash;
            dependencies = [
              pkgs.coreutils
            ];
            isRoot = true;
          };
        };
      };
  };
}
