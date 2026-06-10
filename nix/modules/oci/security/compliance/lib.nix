# CIS compliance checking functions (Trivy)
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
        mkScriptComplianceTrivy = {
          type = types.functionTo types.package;
          description = "Generate Trivy CIS compliance checking script";
          file = "nix/modules/oci/security/compliance/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              containerConfig = perSystemConfig.containers.${containerId}.compliance.trivy;
              archive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
            in
            pkgs.writeShellScriptBin "compliance-trivy-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset
              # Use empty docker config to avoid credentials helper issues
              export DOCKER_CONFIG="$(mktemp -d)"
              TRIVY="${perSystemConfig.packages.trivy}/bin/trivy"
              COMMON_FLAGS="--input ${archive} --compliance ${lib.escapeShellArg containerConfig.spec} --report ${containerConfig.report}"
              # Human-readable output to stdout
              $TRIVY image $COMMON_FLAGS --exit-code 1
              # Write JSON report when CIMERA_REPORT_DIR is set
              if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                mkdir -p "$CIMERA_REPORT_DIR"
                $TRIVY image $COMMON_FLAGS \
                  --exit-code 0 \
                  --format json \
                  --output "$CIMERA_REPORT_DIR/gl-compliance-report.json"
              fi
            '';
        };

        mkAppComplianceTrivy = {
          type = types.functionTo types.attrs;
          description = "Create flake app for Trivy CIS compliance checking";
          file = "nix/modules/oci/security/compliance/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
              globalConfig,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptComplianceTrivy {
                  inherit perSystemConfig containerId globalConfig;
                }
              }/bin/compliance-trivy-${containerId}";
            };
        };
      };
    };
}
