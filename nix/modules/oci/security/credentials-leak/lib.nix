# Credentials leak detection functions (Trivy)
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
        mkScriptCredentialsLeakTrivy = {
          type = types.functionTo types.package;
          description = "Generate Trivy credentials leak detection script";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              archive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
            in
            pkgs.writeShellScriptBin "credentials-leak-trivy-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset
              # Use empty docker config to avoid credentials helper issues
              export DOCKER_CONFIG="$(mktemp -d)"
              TRIVY="${perSystemConfig.packages.trivy}/bin/trivy"
              # Human-readable output to stdout
              $TRIVY fs --scanners secret ${archive}
              # Write GitLab-compatible JSON report when CIMERA_REPORT_DIR is set
              if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                mkdir -p "$CIMERA_REPORT_DIR"
                $TRIVY fs --scanners secret ${archive} \
                  --format json \
                  --output "$CIMERA_REPORT_DIR/gl-secret-detection-report.json"
              fi
            '';
        };

        mkAppCredentialsLeakTrivy = {
          type = types.functionTo types.attrs;
          description = "Create flake app for Trivy credentials leak detection";
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
      };
    };
}
