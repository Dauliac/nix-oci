# Cross-build multi-arch with writeShellApplication.
#
# writeShellApplication creates a custom derivation that doesn't exist in
# pkgsCross, so auto-inference can't resolve it. Use archConfigs to provide
# the cross-compiled variant manually.
#
# For custom packages, consider using a nixpkgs overlay instead -- overlays
# propagate to all pkgsCross sets automatically.
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
            # Manual override needed -- writeShellApplication isn't in pkgsCross
            archConfigs."aarch64-linux".package = myScriptArm;
          };
        };
      };
  };
}
