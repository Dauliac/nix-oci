# SBOM license compliance checking functions (Conftest)
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
        mkScriptLicenseConftest = {
          type = types.functionTo types.package;
          description = "Generate Conftest SBOM license compliance checking script";
          file = "nix/modules/oci/security/license/lib.nix";
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
              mkTransientArchive = ociLib.mkTransientArchive {
                inherit oci;
                skopeo = perSystemConfig.packages.skopeo;
              };
              namespaceFlags = lib.concatMapStringsSep " " (
                ns: "--namespace ${lib.escapeShellArg ns}"
              ) licenseConfig.namespaces;
              effectivePolicyDir =
                if licenseConfig.extraPolicyDirs == [ ] then
                  licenseConfig.policyDir
                else
                  pkgs.symlinkJoin {
                    name = "merged-license-policies-${containerId}";
                    paths = [ licenseConfig.policyDir ] ++ licenseConfig.extraPolicyDirs;
                  };
              configFlag = if sbomConfig.config.enabled then "--config ${sbomConfig.config.path}" else "";
            in
            pkgs.writeShellScriptBin "license-conftest-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset

              CONFTEST="${perSystemConfig.packages.conftest}/bin/conftest"
              SYFT="${perSystemConfig.packages.syft}/bin/syft"
              WORK="$(mktemp -d)"
              trap 'rm -rf "$WORK"' EXIT
              cd "$WORK"

              # Use empty docker config to avoid credentials helper issues
              export DOCKER_CONFIG="$(mktemp -d)"

              # Create transient archive
              ${mkTransientArchive}

              # Generate CycloneDX SBOM from the container image
              $SYFT ${configFlag} archive.tar \
                --output cyclonedx-json="$WORK/sbom.cdx.json"

              # Run conftest license policies against the SBOM
              $CONFTEST test "$WORK/sbom.cdx.json" \
                --policy ${effectivePolicyDir} \
                ${namespaceFlags} \
                --no-color

              # Write JSON report when CIMERA_REPORT_DIR is set
              if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                mkdir -p "$CIMERA_REPORT_DIR"
                # Also save the SBOM for traceability
                cp "$WORK/sbom.cdx.json" "$CIMERA_REPORT_DIR/gl-sbom-license-input.cdx.json"
                $CONFTEST test "$WORK/sbom.cdx.json" \
                  --policy ${effectivePolicyDir} \
                  ${namespaceFlags} \
                  --no-color \
                  --output json \
                  > "$CIMERA_REPORT_DIR/gl-license-conftest-report.json" || true
              fi
            '';
        };

        mkAppLicenseConftest = {
          type = types.functionTo types.attrs;
          description = "Create flake app for Conftest SBOM license compliance checking";
          file = "nix/modules/oci/security/license/lib.nix";
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
      };
    };
}
