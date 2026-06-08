# Cross-build multi-arch with per-arch dependencies.
#
# Shows how to specify cross-compiled dependencies alongside the main package.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          crossBuildWithDeps = {
            package = pkgs.kubectl;
            dependencies = [
              pkgs.bash
              pkgs.coreutils
            ];
            registry = "localhost:5000";
            tags = [ "latest" ];
            multiArch = {
              systems = [
                "x86_64-linux"
                "aarch64-linux"
              ];
              crossBuild.enable = true;
            };
            archConfigs."aarch64-linux" = {
              package = pkgs.pkgsCross.aarch64-multiplatform.kubectl;
              dependencies = [
                pkgs.pkgsCross.aarch64-multiplatform.bash
                pkgs.pkgsCross.aarch64-multiplatform.coreutils
              ];
            };
          };
        };
      };
  };
}
