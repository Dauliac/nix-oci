# Container structure test functions
{
  lib,
  config,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) types;
  thisFile = "nix/modules/oci/_testing/container-structure/lib.nix";
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
          file = thisFile;
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.test.containerStructureTest;
              existingConfigs = lib.filter builtins.pathExists containerConfig.configs;
              coherenceConfigs = lib.optional (containerConfig.coherence or false) (
                ociLib.mkCoherenceCst { inherit perSystemConfig containerId; }
              );
              allConfigs = coherenceConfigs ++ existingConfigs;
              configFlags = lib.concatStringsSep " " (lib.map (config: "--config=${config}") allConfigs);
            in
            if allConfigs == [ ] then
              pkgs.writeShellScriptBin "container-structure-test-${containerId}" ''
                echo "[container-structure-test-${containerId}] no config files configured (expected e.g. at ${toString (lib.head containerConfig.configs)}); skipping" >&2
                exit 0
              ''
            else
              pkgs.writeShellScriptBin "container-structure-test-${containerId}" ''
                ${ociLib.shellPreamble}

                CST="${perSystemConfig.packages.containerStructureTest}/bin/container-structure-test"
                IMAGE="${oci.imageName}:${oci.imageTag}"

                main() {
                  ${oci.copyToDockerDaemon}/bin/copy-to-docker-daemon

                  # Run with text output for console feedback
                  $CST test --image "$IMAGE" --output text ${configFlags}

                  # Generate JUnit report when CIMERA_REPORT_DIR is set
                  ${ociLib.mkReportBlock {
                    reportCommand = ''
                      $CST test --image "$IMAGE" --output junit ${configFlags} \
                        > "$CIMERA_REPORT_DIR/junit.xml" 2>/dev/null
                      echo "JUnit report saved to $CIMERA_REPORT_DIR/junit.xml"
                    '';
                    reportName = "junit.xml";
                  }}
                }

                main "$@"
              '';
        };

        mkAppContainerStructureTest = {
          type = types.functionTo types.attrs;
          description = "Create flake app for container-structure-test";
          file = thisFile;
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
