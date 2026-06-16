# Container image linting functions (Dockle)
import ../../../../lib/mkLibModule.nix (
  {
    lib,
    ociLib,
    ...
  }:
  let
    thisFile = "nix/modules/oci/security/lint/lib.nix";

    exitLevelToCode = {
      "info" = "INFO";
      "warn" = "WARN";
      "fatal" = "FATAL";
    };
  in
  {
    mkScriptLintDockle = {
      type = lib.types.functionTo lib.types.package;
      description = "Generate Dockle container image linting script";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
          globalConfig,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          containerConfig = perSystemConfig.containers.${containerId}.lint.dockle;
          ignoreFlags = lib.concatMapStringsSep " " (
            id: "--ignore ${lib.escapeShellArg id}"
          ) containerConfig.ignore;
          exitLevel = exitLevelToCode.${containerConfig.exitLevel};
          dockleBin = "${perSystemConfig.packages.dockle}/bin/dockle";
          commonFlags = "--input archive.tar --exit-level ${exitLevel} ${ignoreFlags}";
        in
        ociLib.mkArchiveScanScript {
          name = "lint-dockle-${containerId}";
          inherit oci;
          skopeo = perSystemConfig.packages.skopeo;
          scanCommand = ''
            ${dockleBin} ${commonFlags} --exit-code 1
          '';
          reportBlock = ociLib.mkReportBlock {
            reportCommand = ''
              ${dockleBin} ${commonFlags} \
                --exit-code 0 \
                --format json \
                --output "$CIMERA_REPORT_DIR/gl-lint-dockle-report.json"
            '';
            reportName = "gl-lint-dockle-report.json";
          };
        };
    };

    mkCheckLintDockle = {
      type = lib.types.functionTo lib.types.package;
      description = "Create derivation check for Dockle container image linting";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
          globalConfig,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          containerConfig = perSystemConfig.containers.${containerId}.lint.dockle;
          ignoreFlags = lib.concatMapStringsSep " " (
            id: "--ignore ${lib.escapeShellArg id}"
          ) containerConfig.ignore;
          exitLevel = exitLevelToCode.${containerConfig.exitLevel};
        in
        ociLib.mkArchiveScanCheck {
          name = "lint-dockle-${containerId}";
          metaDescription = "Run Dockle lint on ${containerId}.";
          inherit oci;
          skopeo = perSystemConfig.packages.skopeo;
          toolPackages = [ perSystemConfig.packages.dockle ];
          checkCommand = ''
            ${perSystemConfig.packages.dockle}/bin/dockle \
              --input archive.tar \
              --exit-level ${exitLevel} \
              ${ignoreFlags} \
              --exit-code 1
          '';
        };
    };

    mkAppLintDockle = {
      type = lib.types.functionTo lib.types.attrs;
      description = "Create flake app for Dockle container image linting";
      file = thisFile;
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
  }
)
