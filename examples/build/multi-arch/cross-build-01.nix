# Cross-build multi-arch: single machine builds all arches locally.
#
# Produces:
#   - `oci-multiarch-<name>` package (OCI directory layout)
#   - `oci-push-multiarch-<name>` app (push to registry)
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          crossBuild = {
            package = pkgs.hello;
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
            archConfigs."aarch64-linux" = {
              package = pkgs.pkgsCross.aarch64-multiplatform.hello;
            };
          };
        };
      };
  };
}
