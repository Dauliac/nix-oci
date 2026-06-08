# Cross-build multi-arch with writeShellApplication.
#
# Shows that cross-build works with custom entrypoints and
# writeShellApplication-based containers.
{ ... }:
{
  config = {
    perSystem =
      { pkgs, ... }:
      let
        myScript = pkgs.writeShellApplication {
          name = "my-app";
          runtimeInputs = [ pkgs.curl ];
          text = ''
            echo "Hello from $(uname -m)"
            curl --version
          '';
        };
        myScriptArm = pkgs.pkgsCross.aarch64-multiplatform.writeShellApplication {
          name = "my-app";
          runtimeInputs = [ pkgs.pkgsCross.aarch64-multiplatform.curl ];
          text = ''
            echo "Hello from $(uname -m)"
            curl --version
          '';
        };
      in
      {
        config.oci.containers = {
          crossBuildWriteShell = {
            package = myScript;
            registry = "localhost:5000";
            tags = [ "latest" ];
            multiArch = {
              systems = [
                "x86_64-linux"
                "aarch64-linux"
              ];
              crossBuild.enable = true;
            };
            archConfigs."aarch64-linux".package = myScriptArm;
          };
        };
      };
  };
}
