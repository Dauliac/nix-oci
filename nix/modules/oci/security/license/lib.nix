# SBOM license compliance checking functions (Conftest)
import ../../../../lib/mkLibModule.nix (
  {
    lib,
    ociLib,
    ...
  }:
  let
    thisFile = "nix/modules/oci/security/license/lib.nix";
  in
  {
    mkScriptLicenseConftest = {
      type = lib.types.functionTo lib.types.package;
      description = "Generate Conftest SBOM license compliance checking script";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
          globalConfig,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          containerConfig = perSystemConfig.containers.${containerId};
          licenseConfig = containerConfig.license.conftest;
          sbomConfig = containerConfig.sbom.syft;
          namespaceFlags = lib.concatMapStringsSep " " (
            ns: "--namespace ${lib.escapeShellArg ns}"
          ) licenseConfig.namespaces;
          effectivePolicyDir = ociLib.mkMergedPolicyDir {
            name = "license-${containerId}";
            baseDir = licenseConfig.policyDir;
            extraDirs = licenseConfig.extraPolicyDirs;
          };
          configFlag = if sbomConfig.config.enabled then "--config ${sbomConfig.config.path}" else "";
          conftestBin = "${perSystemConfig.packages.conftest}/bin/conftest";
          syftBin = "${perSystemConfig.packages.syft}/bin/syft";
        in
        ociLib.mkArchiveScanScript {
          name = "license-conftest-${containerId}";
          inherit oci;
          skopeo = perSystemConfig.packages.skopeo;
          scanCommand = ''
            # Generate CycloneDX SBOM from the container image
            ${syftBin} ${configFlag} archive.tar \
              --output cyclonedx-json="$WORK/sbom.cdx.json"

            # Run conftest license policies against the SBOM
            ${conftestBin} test "$WORK/sbom.cdx.json" \
              --policy ${effectivePolicyDir} \
              ${namespaceFlags} \
              --no-color
          '';
          reportBlock = ociLib.mkReportBlock {
            reportCommand = ''
              # Also save the SBOM for traceability
              cp "$WORK/sbom.cdx.json" "$CIMERA_REPORT_DIR/gl-sbom-license-input.cdx.json"
              ${conftestBin} test "$WORK/sbom.cdx.json" \
                --policy ${effectivePolicyDir} \
                ${namespaceFlags} \
                --no-color \
                --output json \
                > "$CIMERA_REPORT_DIR/gl-license-conftest-report.json" || true
            '';
            reportName = "gl-license-conftest-report.json";
          };
        };
    };

    mkAppLicenseConftest = {
      type = lib.types.functionTo lib.types.attrs;
      description = "Create flake app for Conftest SBOM license compliance checking";
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
            ociLib.mkScriptLicenseConftest {
              inherit perSystemConfig containerId globalConfig;
            }
          }/bin/license-conftest-${containerId}";
        };
    };
  }
)
