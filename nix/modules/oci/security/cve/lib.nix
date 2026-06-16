# CVE scanning functions (Trivy, Grype, Vulnix)
import ../../../../lib/mkLibModule.nix (
  {
    pkgs,
    lib,
    ociLib,
    ...
  }:
  let
    thisFile = "nix/modules/oci/security/cve/lib.nix";
  in
  {
    mkScriptCVETrivy = {
      type = lib.types.functionTo lib.types.package;
      description = "Generate Trivy CVE scanning script";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
          globalConfig,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          containerConfig = perSystemConfig.containers.${containerId}.cve.trivy;
          ignoreFileFlag =
            if containerConfig.ignore.fileEnabled then "--ignorefile ${containerConfig.ignore.path}" else "";
          extraIgnoreFile = pkgs.writeText "extra-ignore.ignore" ''
            ${lib.concatMapStrings (ignore: "${ignore}\n") (globalConfig.cve.trivy.ignore.extra or [ ])}
          '';
          extraIgnoreFileFlag =
            if (lib.length (globalConfig.cve.trivy.ignore.extra or [ ])) > 0 then
              "--ignorefile ${extraIgnoreFile}"
            else
              "";
          containerExtraIgnoreFile = pkgs.writeText "container-extra-ignore.ignore" ''
            ${lib.concatMapStrings (ignore: "${ignore}\n") containerConfig.ignore.extra}
          '';
          containerExtraIgnoreFileFlag =
            if (lib.length containerConfig.ignore.extra) > 0 then
              "--ignorefile ${containerExtraIgnoreFile}"
            else
              "";
          trivyBin = "${perSystemConfig.packages.trivy}/bin/trivy";
          commonFlags = "--input archive.tar ${ignoreFileFlag} ${extraIgnoreFileFlag} ${containerExtraIgnoreFileFlag} --scanners vuln";
        in
        ociLib.mkArchiveScanScript {
          name = "trivy-${containerId}";
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
                --output "$CIMERA_REPORT_DIR/gl-container-scanning-report.json"
            '';
            reportName = "gl-container-scanning-report.json";
          };
        };
    };

    mkAppCVETrivy = {
      type = lib.types.functionTo lib.types.attrs;
      description = "Create flake app for Trivy CVE scanning";
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
            ociLib.mkScriptCVETrivy {
              inherit perSystemConfig containerId globalConfig;
            }
          }/bin/trivy-${containerId}";
        };
    };

    mkScriptCVEGrype = {
      type = lib.types.functionTo lib.types.package;
      description = "Generate Grype CVE scanning script";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          containerConfig = perSystemConfig.containers.${containerId}.cve.grype;
          configFlag =
            if containerConfig.config.enabled then "--config ${containerConfig.config.path}" else "";
          grypeBin = "${perSystemConfig.packages.grype}/bin/grype";
        in
        ociLib.mkArchiveScanScript {
          name = "grype-${containerId}";
          inherit oci;
          skopeo = perSystemConfig.packages.skopeo;
          scanCommand = ''
            ${grypeBin} ${configFlag} archive.tar
          '';
          reportBlock = ociLib.mkReportBlock {
            reportCommand = ''
              ${grypeBin} ${configFlag} archive.tar \
                --output json \
                --file "$CIMERA_REPORT_DIR/gl-dependency-scanning-report.json"
            '';
            reportName = "gl-dependency-scanning-report.json";
          };
        };
    };

    mkAppCVEGrype = {
      type = lib.types.functionTo lib.types.attrs;
      description = "Create flake app for Grype CVE scanning";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        {
          type = "app";
          program = "${
            ociLib.mkScriptCVEGrype {
              inherit perSystemConfig containerId;
            }
          }/bin/grype-${containerId}";
        };
    };

    mkScriptCVEVulnix = {
      type = lib.types.functionTo lib.types.package;
      description = "Generate vulnix CVE scanning script";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        let
          oci = perSystemConfig.internal.OCIs.${containerId};
          containerConfig = perSystemConfig.containers.${containerId}.cve.vulnix;
          whitelistFlag =
            if containerConfig.whitelist.enabled then "--whitelist ${containerConfig.whitelist.path}" else "";
          vulnixBin = "${perSystemConfig.packages.vulnix}/bin/vulnix";
        in
        ociLib.mkArchiveScanScript {
          name = "vulnix-${containerId}";
          inherit oci;
          skopeo = perSystemConfig.packages.skopeo;
          needsDockerConfig = false;
          needsArchive = false;
          scanCommand = ''
            ${vulnixBin} ${whitelistFlag} --show-description ${oci}
          '';
          reportBlock = ociLib.mkReportBlock {
            reportCommand = ''
              ${vulnixBin} ${whitelistFlag} --json ${oci} \
                > "$CIMERA_REPORT_DIR/gl-vulnix-cve-report.json" || true
            '';
            reportName = "gl-vulnix-cve-report.json";
          };
        };
    };

    mkAppCVEVulnix = {
      type = lib.types.functionTo lib.types.attrs;
      description = "Create flake app for vulnix CVE scanning";
      file = thisFile;
      fn =
        {
          perSystemConfig,
          containerId,
        }:
        {
          type = "app";
          program = "${
            ociLib.mkScriptCVEVulnix {
              inherit perSystemConfig containerId;
            }
          }/bin/vulnix-${containerId}";
        };
    };
  }
)
