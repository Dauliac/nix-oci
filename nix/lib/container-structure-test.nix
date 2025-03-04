{
  lib,
  config,
  ...
}:
let
  inherit (lib)
    mkOption
    mdDoc
    types
    ;
  cfg = config.lib;
in
{
  options.lib = {
    mkScriptContainerStructureTest = mkOption {
      description = mdDoc "A function to create a check that runs container-structure-test on a built image using podman.";
      type = types.functionTo types.package;
      default =
        {
          pkgs,
          perSystemConfig,
          containerId,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          configFlags = lib.concatStringsSep " " (
            lib.map (
              config: "--config=${config}"
            ) perSystemConfig.containers.${containerId}.test.containerStructureTest.configs
          );
        in
        pkgs.writeShellScriptBin "container-structure-test" ''
          set -o errexit
          set -o nounset
          set -o pipefail

          main() {
            ${oci.copyToDockerDaemon}/bin/copy-to-docker-daemon
            ${perSystemConfig.packages.containerStructureTest}/bin/container-structure-test \
              test --image "${oci.imageName}:${oci.imageTag}" \
              --output text \
              ${configFlags}
          }

          main "$@"
        '';
    };
    mkAppContainerStructureTest = mkOption {
      description = mdDoc "A function to create a check that runs container-structure-test on a built image using podman.";
      type = types.functionTo types.attrs;
      default = args: {
        type = "app";
        program = cfg.mkScriptContainerStructureTest args;
      };
    };
  };
}
