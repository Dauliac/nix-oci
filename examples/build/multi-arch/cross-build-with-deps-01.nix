# Cross-build multi-arch with dependencies.
#
# Both the main package and dependencies are auto-inferred via pkgsCross.
# Dependencies whose pname doesn't match a pkgsCross attr are silently
# dropped — override via archConfigs if needed.
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
              pkgs.coreutils
              pkgs.curl
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
          };
        };
      };
  };
}
