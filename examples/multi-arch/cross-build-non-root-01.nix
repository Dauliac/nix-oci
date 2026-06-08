# Cross-build multi-arch with non-root user.
#
# Multi-arch works with all container options including user, labels, etc.
# Only the package and dependencies change per architecture.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          crossBuildNonRoot = {
            package = pkgs.hello;
            user = "appuser";
            labels = {
              "org.opencontainers.image.source" = "https://github.com/example/repo";
              "org.opencontainers.image.description" = "Multi-arch non-root container";
            };
            registry = "localhost:5000";
            tags = [
              "1.0.0"
              "latest"
            ];
            multiArch = {
              systems = [
                "x86_64-linux"
                "aarch64-linux"
              ];
              crossBuild.enable = true;
            };
            archConfigs."aarch64-linux".package = pkgs.pkgsCross.aarch64-multiplatform.hello;
          };
        };
      };
  };
}
