# Credentials leak detection functions (Trivy)
import ../../../../lib/mkLibModule.nix (
  {
    lib,
    ociLib,
    ...
  }:
  let
    thisFile = "nix/modules/oci/security/credentials-leak/lib.nix";
  in
  {
    mkScriptCredentialsLeakTrivy = {
      type = lib.types.functionTo lib.types.package;
      description = "Generate Trivy credentials leak detection script";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          trivyBin = "${perSystemConfig.packages.trivy}/bin/trivy";
        in
        ociLib.mkArchiveScanScript {
          name = "credentials-leak-trivy-${containerId}";
          inherit oci;
          skopeo = perSystemConfig.packages.skopeo;
          scanCommand = ''
            ${trivyBin} fs --scanners secret archive.tar
          '';
          reportBlock = ociLib.mkReportBlock {
            reportCommand = ''
              ${trivyBin} fs --scanners secret archive.tar \
                --format json \
                --output "$CIMERA_REPORT_DIR/gl-secret-detection-report.json"
            '';
            reportName = "gl-secret-detection-report.json";
          };
        };
    };

    mkCheckCredentialsLeakTrivy = {
      type = lib.types.functionTo lib.types.package;
      description = "Create derivation check for Trivy credentials leak detection";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
        in
        ociLib.mkArchiveScanCheck {
          name = "credentials-leak-trivy-${containerId}";
          metaDescription = "Run Trivy credentials leak scan on ${containerId}.";
          inherit oci;
          skopeo = perSystemConfig.packages.skopeo;
          toolPackages = [ perSystemConfig.packages.trivy ];
          checkCommand = ''
            ${perSystemConfig.packages.trivy}/bin/trivy fs --scanners secret archive.tar
          '';
        };
    };

    mkAppCredentialsLeakTrivy = {
      type = lib.types.functionTo lib.types.attrs;
      description = "Create flake app for Trivy credentials leak detection";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        {
          type = "app";
          program = "${
            ociLib.mkScriptCredentialsLeakTrivy {
              inherit perSystemConfig containerId;
            }
          }/bin/credentials-leak-trivy-${containerId}";
        };
    };
  }
)
