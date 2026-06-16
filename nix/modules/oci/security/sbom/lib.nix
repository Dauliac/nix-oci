# SBOM generation functions (Syft)
import ../../../../lib/mkLibModule.nix (
  {
    lib,
    ociLib,
    ...
  }:
  let
    thisFile = "nix/modules/oci/security/sbom/lib.nix";
  in
  {
    mkScriptSBOMSyft = {
      type = lib.types.functionTo lib.types.package;
      description = "Generate Syft SBOM generation script";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          containerConfig = perSystemConfig.containers.${containerId}.sbom.syft;
          configFlag =
            if containerConfig.config.enabled then "--config ${containerConfig.config.path}" else "";
          syftBin = "${perSystemConfig.packages.syft}/bin/syft";
        in
        ociLib.mkArchiveScanScript {
          name = "sbom-syft-${containerId}";
          inherit oci;
          skopeo = perSystemConfig.packages.skopeo;
          scanCommand = ''
            ${syftBin} ${configFlag} archive.tar
          '';
          reportBlock = ociLib.mkReportBlock {
            reportCommand = ''
              ${syftBin} ${configFlag} archive.tar \
                --output cyclonedx-json="$CIMERA_REPORT_DIR/gl-sbom-report.cdx.json"
            '';
            reportName = "gl-sbom-report.cdx.json";
          };
        };
    };

    mkCheckSBOMSyft = {
      type = lib.types.functionTo lib.types.package;
      description = "Create derivation check that generates Syft SBOM (validates SBOM can be produced)";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          containerConfig = perSystemConfig.containers.${containerId}.sbom.syft;
          configFlag =
            if containerConfig.config.enabled then "--config ${containerConfig.config.path}" else "";
        in
        ociLib.mkArchiveScanCheck {
          name = "sbom-syft-${containerId}";
          metaDescription = "Generate Syft SBOM for ${containerId}.";
          inherit oci;
          skopeo = perSystemConfig.packages.skopeo;
          toolPackages = [ perSystemConfig.packages.syft ];
          checkCommand = ''
            ${perSystemConfig.packages.syft}/bin/syft ${configFlag} archive.tar \
              --output cyclonedx-json="$out"
          '';
        };
    };

    mkAppSBOMSyft = {
      type = lib.types.functionTo lib.types.attrs;
      description = "Create flake app for Syft SBOM generation";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        {
          type = "app";
          program = "${
            ociLib.mkScriptSBOMSyft {
              inherit perSystemConfig containerId;
            }
          }/bin/sbom-syft-${containerId}";
        };
    };
  }
)
