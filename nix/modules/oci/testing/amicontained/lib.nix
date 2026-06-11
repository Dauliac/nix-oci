# Container introspection functions (amicontained)
#
# amicontained is bind-mounted from the Nix store into the container
# at runtime — the production image is never modified. It reports:
# - Container runtime (Docker, Podman, LXC, etc.)
# - Available Linux capabilities
# - Seccomp profile status (enabled/disabled, blocked syscalls)
# - User namespace status
# - AppArmor profile
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
        mkScriptAmicontained = {
          type = types.functionTo types.package;
          description = "Generate amicontained container introspection script";
          file = "nix/modules/oci/testing/amicontained/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              amicontained = perSystemConfig.packages.amicontained;
            in
            pkgs.writeShellScriptBin "amicontained-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset

              AMICONTAINED="${amicontained}/bin/amicontained"
              IMAGE="${oci.imageName}:${oci.imageTag}"

              main() {
                # Load the image into the daemon
                ${oci.copyToDockerDaemon}/bin/copy-to-docker-daemon

                echo "=== amicontained introspection: $IMAGE ==="
                echo ""

                # Run amicontained bind-mounted into the container.
                # The binary is injected read-only from the Nix store;
                # the production image is untouched.
                OUTPUT=$(podman run --rm \
                  -v "$AMICONTAINED:/amicontained:ro" \
                  --entrypoint /amicontained \
                  "$IMAGE" 2>&1) || true

                echo "$OUTPUT"

                # Write report when CIMERA_REPORT_DIR is set
                if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                  mkdir -p "$CIMERA_REPORT_DIR"
                  echo "$OUTPUT" > "$CIMERA_REPORT_DIR/amicontained-report.txt"
                fi

                # Check for concerning findings
                ISSUES=0

                if echo "$OUTPUT" | grep -qi "Is Privileged.*true"; then
                  echo ""
                  echo "FAIL: Container is running in privileged mode"
                  ISSUES=$((ISSUES + 1))
                fi

                if echo "$OUTPUT" | grep -qi "Seccomp.*disabled"; then
                  echo ""
                  echo "WARN: Seccomp is disabled — no syscall filtering"
                  ISSUES=$((ISSUES + 1))
                fi

                echo ""
                if [ "$ISSUES" -gt 0 ]; then
                  echo "amicontained found $ISSUES issue(s)"
                  exit 1
                else
                  echo "amicontained: no critical issues detected"
                fi
              }

              main "$@"
            '';
        };

        mkAppAmicontained = {
          type = types.functionTo types.attrs;
          description = "Create flake app for amicontained container introspection";
          file = "nix/modules/oci/testing/amicontained/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptAmicontained {
                  inherit perSystemConfig containerId;
                }
              }/bin/amicontained-${containerId}";
            };
        };

        mkCheckAmicontained = {
          type = types.functionTo types.package;
          description = "Run amicontained as a hermetic check via podman-in-sandbox";
          file = "nix/modules/oci/testing/amicontained/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              amicontained = perSystemConfig.packages.amicontained;
              dockerArchive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              imageRef = "localhost/${oci.imageName}:${oci.imageTag}";
            in
            ociLib.mkPodmanSandboxCheck {
              name = "amicontained-${containerId}";
              inherit dockerArchive imageRef;
              testScript = ''
                OUTPUT=$(podman "''${PODMAN_FLAGS[@]}" run --rm \
                  -v "${amicontained}/bin/amicontained:/amicontained:ro" \
                  --entrypoint /amicontained \
                  "${imageRef}" 2>&1) || true

                echo "$OUTPUT"

                # Fail on privileged mode
                if echo "$OUTPUT" | grep -qi "Is Privileged.*true"; then
                  echo "FAIL: Container is running in privileged mode" >&2
                  exit 1
                fi
              '';
            };
        };
      };
    };
}
