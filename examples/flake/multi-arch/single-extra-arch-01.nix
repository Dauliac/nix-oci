# Single extra arch: add arm64 to an amd64-native build via cross-compilation.
#
# Cross package auto-inferred -- just list the target systems.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      {
        config.oci.containers = {
          singleExtraArch = {
            package = pkgs.hello;
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
