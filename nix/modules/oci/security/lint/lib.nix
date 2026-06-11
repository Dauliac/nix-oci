# Container image linting functions (Dockle)
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

      exitLevelToCode = {
        "info" = "INFO";
        "warn" = "WARN";
        "fatal" = "FATAL";
      };
    in
    {
      nix-lib.lib.oci = {
        mkScriptLintDockle = {
          type = types.functionTo types.package;
          description = "Generate Dockle container image linting script";
          file = "nix/modules/oci/security/lint/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.lint.dockle;
              archive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              ignoreFlags = lib.concatMapStringsSep " " (
                id: "--ignore ${lib.escapeShellArg id}"
              ) containerConfig.ignore;
              exitLevel = exitLevelToCode.${containerConfig.exitLevel};
            in
            pkgs.writeShellScriptBin "lint-dockle-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset
              DOCKLE="${perSystemConfig.packages.dockle}/bin/dockle"
              COMMON_FLAGS="--input ${archive} --exit-level ${exitLevel} ${ignoreFlags}"
              # Human-readable output to stdout
              $DOCKLE $COMMON_FLAGS --exit-code 1
              # Write JSON report when CIMERA_REPORT_DIR is set
              if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                mkdir -p "$CIMERA_REPORT_DIR"
                $DOCKLE $COMMON_FLAGS \
                  --exit-code 0 \
                  --format json \
                  --output "$CIMERA_REPORT_DIR/gl-lint-dockle-report.json"
              fi
            '';
        };

        mkCheckLintDockle = {
          type = types.functionTo types.package;
          description = "Create derivation check for Dockle container image linting";
          file = "nix/modules/oci/security/lint/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.lint.dockle;
              archive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              ignoreFlags = lib.concatMapStringsSep " " (
                id: "--ignore ${lib.escapeShellArg id}"
              ) containerConfig.ignore;
              exitLevel = exitLevelToCode.${containerConfig.exitLevel};
            in
            pkgs.runCommandLocal "lint-dockle-${containerId}"
              {
                buildInputs = [ perSystemConfig.packages.dockle ];
                meta.description = "Run Dockle lint on ${containerId}.";
              }
              ''
                set -o errexit
                set -o pipefail
                set -o nounset
                ${perSystemConfig.packages.dockle}/bin/dockle \
                  --input ${archive} \
                  --exit-level ${exitLevel} \
                  ${ignoreFlags} \
                  --exit-code 1
                touch $out
              '';
        };

        mkAppLintDockle = {
          type = types.functionTo types.attrs;
          description = "Create flake app for Dockle container image linting";
          file = "nix/modules/oci/security/lint/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptLintDockle {
                  inherit perSystemConfig containerId globalConfig;
                }
              }/bin/lint-dockle-${containerId}";
            };
        };
      };
    };
}
