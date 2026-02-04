# Container structure test functions
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
        mkScriptContainerStructureTest = {
          type = types.functionTo types.package;
          description = "Generate container-structure-test script";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.test.containerStructureTest;
              configFlags = lib.concatStringsSep " " (
                lib.map (config: "--config=${config}") containerConfig.configs
              );
            in
            pkgs.writeShellScriptBin "container-structure-test-${containerId}" ''
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

        mkAppContainerStructureTest = {
          type = types.functionTo types.attrs;
          description = "Create flake app for container-structure-test";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptContainerStructureTest {
                  inherit perSystemConfig containerId;
                }
              }/bin/container-structure-test-${containerId}";
            };
        };
      };
    };
}
