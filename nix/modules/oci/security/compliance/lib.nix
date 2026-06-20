# CIS compliance checking functions (Trivy)
import ../../../../lib/mkLibModule.nix (
  {
    lib,
    ociLib,
    ...
  }:
  let
    thisFile = "nix/modules/oci/security/compliance/lib.nix";
  in
  {
    mkScriptComplianceTrivy = {
      type = lib.types.functionTo lib.types.package;
      description = "Generate Trivy CIS compliance checking script";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          containerConfig = perSystemConfig.containers.${containerId}.compliance.trivy;
          trivyBin = "${perSystemConfig.packages.trivy}/bin/trivy";
          commonFlags = "--input archive.tar --compliance ${lib.escapeShellArg containerConfig.spec} --report ${containerConfig.report}";
        in
        ociLib.mkArchiveScanScript {
          name = "compliance-trivy-${containerId}";
          inherit oci;
          skopeo = perSystemConfig.packages.skopeo;
          scanCommand = ''
            ${trivyBin} image ${commonFlags} --exit-code 1
          '';
          reportBlock = ociLib.mkReportBlock {
            reportCommand = ''
              ${trivyBin} image ${commonFlags} \
                --exit-code 0 \
                --format json \
                --output "$CIMERA_REPORT_DIR/gl-compliance-report.json"
            '';
            reportName = "gl-compliance-report.json";
          };
        };
    };

    mkAppComplianceTrivy = {
      type = lib.types.functionTo lib.types.attrs;
      description = "Create flake app for Trivy CIS compliance checking";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        {
          type = "app";
          program = "${
            ociLib.mkScriptComplianceTrivy {
              inherit perSystemConfig containerId;
            }
          }/bin/compliance-trivy-${containerId}";
        };
    };
  }
)
