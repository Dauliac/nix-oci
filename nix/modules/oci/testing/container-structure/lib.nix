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
              # Filter out configs whose file doesn't exist at eval time.
              # Interpolating `${path}` copies the file to the Nix store and
              # fails eval if missing, so we can't defer the check to runtime.
              existingConfigs = lib.filter builtins.pathExists containerConfig.configs;
              configFlags = lib.concatStringsSep " " (lib.map (config: "--config=${config}") existingConfigs);
            in
            if existingConfigs == [ ] then
              pkgs.writeShellScriptBin "container-structure-test-${containerId}" ''
                echo "[container-structure-test-${containerId}] no config files configured (expected e.g. at ${toString (lib.head containerConfig.configs)}); skipping" >&2
                exit 0
              ''
            else
              pkgs.writeShellScriptBin "container-structure-test-${containerId}" ''
                set -o errexit
                set -o nounset
                set -o pipefail

                CST="${perSystemConfig.packages.containerStructureTest}/bin/container-structure-test"
                IMAGE="${oci.imageName}:${oci.imageTag}"

                main() {
                  ${oci.copyToDockerDaemon}/bin/copy-to-docker-daemon

                  # Run with text output for console feedback
                  $CST test --image "$IMAGE" --output text ${configFlags}

                  # Generate JUnit report when CIMERA_REPORT_DIR is set
                  # (injected by the cimera task wrapper for all tasks)
                  if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                    mkdir -p "$CIMERA_REPORT_DIR"
                    $CST test --image "$IMAGE" --output junit ${configFlags} \
                      > "$CIMERA_REPORT_DIR/junit.xml" 2>/dev/null
                    echo "JUnit report saved to $CIMERA_REPORT_DIR/junit.xml"
                  fi
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
