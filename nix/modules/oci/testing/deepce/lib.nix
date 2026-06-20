# Container escape detection functions (DEEPCE)
#
# Uses mkContainerProbe with needsShell=true — busybox is injected
# automatically as the shell interpreter.
{
  lib,
  config,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) types;
in
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
    in
    {
      nix-lib.lib.oci = {
        mkScriptDeepce = {
          type = types.functionTo types.package;
          description = "Generate DEEPCE container escape detection script";
          file = "nix/modules/oci/testing/deepce/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
            in
            ociLib.mkContainerProbe {
              name = "deepce-${containerId}";
              inherit oci;
              probe = "${perSystemConfig.packages.deepce}/bin/deepce.sh";
              needsShell = true;
              args = "--no-network --no-colors";
              failPatterns = [
                {
                  pattern = "Docker Socket Found";
                  message = "Docker socket is exposed inside the container";
                }
                {
                  pattern = "Privileged Mode";
                  message = "Container is running in privileged mode";
                }
              ];
            };
        };

        mkAppDeepce = {
          type = types.functionTo types.attrs;
          description = "Create flake app for DEEPCE container escape detection";
          file = "nix/modules/oci/testing/deepce/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptDeepce {
                  inherit perSystemConfig containerId;
                }
              }/bin/deepce-${containerId}";
            };
        };

        mkCheckDeepce = {
          type = types.functionTo types.package;
          description = "Run DEEPCE as a hermetic check via podman-in-sandbox";
          file = "nix/modules/oci/testing/deepce/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
            in
            ociLib.mkHermeticContainerProbe {
              name = "deepce-${containerId}";
              dockerArchive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              imageRef = "localhost/${oci.imageName}:${oci.imageTag}";
              probe = "${perSystemConfig.packages.deepce}/bin/deepce.sh";
              needsShell = true;
              args = "--no-network --no-colors";
              failPatterns = [
                {
                  pattern = "Docker Socket Found";
                  message = "Docker socket exposed";
                }
                {
                  pattern = "Privileged Mode";
                  message = "Privileged mode detected";
                }
              ];
            };
        };
      };
    };
}
