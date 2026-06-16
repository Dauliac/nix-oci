# CVE scanning functions (Trivy, Grype)
{
  lib,
  config,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) types;
  cfg = config;
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
        mkScriptCVETrivy = {
          type = types.functionTo types.package;
          description = "Generate Trivy CVE scanning script";
          file = "nix/modules/oci/security/cve/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.cve.trivy;
              mkTransientArchive = ociLib.mkTransientArchive {
                inherit oci;
                skopeo = perSystemConfig.packages.skopeo;
              };
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
            in
            pkgs.writeShellScriptBin "trivy-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset
              # Use empty docker config to avoid credentials helper issues
              export DOCKER_CONFIG="$(mktemp -d)"
              WORK="$(mktemp -d)"
              trap 'rm -rf "$WORK"' EXIT
              cd "$WORK"
              ${mkTransientArchive}
              TRIVY="${perSystemConfig.packages.trivy}/bin/trivy"
              COMMON_FLAGS="--input archive.tar ${ignoreFileFlag} ${extraIgnoreFileFlag} ${containerExtraIgnoreFileFlag} --scanners vuln"
              # Human-readable output to stdout
              $TRIVY image $COMMON_FLAGS --exit-code 1
              # Write GitLab-compatible JSON report when CIMERA_REPORT_DIR is set
              if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                mkdir -p "$CIMERA_REPORT_DIR"
                $TRIVY image $COMMON_FLAGS \
                  --exit-code 0 \
                  --format json \
                  --output "$CIMERA_REPORT_DIR/gl-container-scanning-report.json"
              fi
            '';
        };

        mkAppCVETrivy = {
          type = types.functionTo types.attrs;
          description = "Create flake app for Trivy CVE scanning";
          file = "nix/modules/oci/security/cve/lib.nix";
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
          type = types.functionTo types.package;
          description = "Generate Grype CVE scanning script";
          file = "nix/modules/oci/security/cve/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.cve.grype;
              mkTransientArchive = ociLib.mkTransientArchive {
                inherit oci;
                skopeo = perSystemConfig.packages.skopeo;
              };
              configFlag =
                if containerConfig.config.enabled then "--config ${containerConfig.config.path}" else "";
            in
            pkgs.writeShellScriptBin "grype-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset
              # Use empty docker config to avoid credentials helper issues
              export DOCKER_CONFIG="$(mktemp -d)"
              WORK="$(mktemp -d)"
              trap 'rm -rf "$WORK"' EXIT
              cd "$WORK"
              ${mkTransientArchive}
              GRYPE="${perSystemConfig.packages.grype}/bin/grype"
              # Human-readable output to stdout
              $GRYPE ${configFlag} archive.tar
              # Write GitLab-compatible JSON report when CIMERA_REPORT_DIR is set
              if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                mkdir -p "$CIMERA_REPORT_DIR"
                $GRYPE ${configFlag} archive.tar \
                  --output json \
                  --file "$CIMERA_REPORT_DIR/gl-dependency-scanning-report.json"
              fi
            '';
        };

        mkAppCVEGrype = {
          type = types.functionTo types.attrs;
          description = "Create flake app for Grype CVE scanning";
          file = "nix/modules/oci/security/cve/lib.nix";
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
          type = types.functionTo types.package;
          description = "Generate vulnix CVE scanning script";
          file = "nix/modules/oci/security/cve/lib.nix";
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
            in
            pkgs.writeShellScriptBin "vulnix-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset
              VULNIX="${perSystemConfig.packages.vulnix}/bin/vulnix"
              $VULNIX ${whitelistFlag} --show-description ${oci}
              if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                mkdir -p "$CIMERA_REPORT_DIR"
                $VULNIX ${whitelistFlag} --json ${oci} \
                  > "$CIMERA_REPORT_DIR/gl-vulnix-cve-report.json" || true
              fi
            '';
        };

        mkAppCVEVulnix = {
          type = types.functionTo types.attrs;
          description = "Create flake app for vulnix CVE scanning";
          file = "nix/modules/oci/security/cve/lib.nix";
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
      };
    };
}
