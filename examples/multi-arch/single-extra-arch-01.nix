# Single extra arch: add arm64 to an amd64-native build via cross-compilation.
#
# Only one non-native arch is added. The native arch is automatically
# included via archConfigs defaults.
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
            archConfigs."aarch64-linux".package = pkgs.pkgsCross.aarch64-multiplatform.hello;
          };
        };
      };
  };
}
