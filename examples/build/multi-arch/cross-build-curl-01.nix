# Cross-build multi-arch curl image.
#
# Builds curl for both amd64 and arm64 from a single machine.
# Cross package auto-inferred — no archConfigs needed.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          crossBuildCurl = {
            package = pkgs.curl;
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
          };
        };
      };
  };
}
