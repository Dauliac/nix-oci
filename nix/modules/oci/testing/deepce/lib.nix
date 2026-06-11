# Container escape detection functions (DEEPCE)
#
# DEEPCE is a pure sh script — hardened images may not have a shell.
# We solve this by bind-mounting both busybox (as the sh interpreter)
# and the deepce script from the Nix store. The production image is
# never modified.
#
# By default, DEEPCE runs in enumeration-only mode (no exploits).
# It reports: Docker socket exposure, privileged mode, dangerous
# capabilities, mounted filesystems, namespace sharing, and more.
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
        mkScriptDeepce = {
          type = types.functionTo types.package;
          description = "Generate DEEPCE container escape detection script";
          file = "nix/modules/oci/testing/deepce/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              deepce = perSystemConfig.packages.deepce;
              busybox = pkgs.pkgsStatic.busybox;
            in
            pkgs.writeShellScriptBin "deepce-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset

              DEEPCE="${deepce}/bin/deepce.sh"
              BUSYBOX="${busybox}/bin/busybox"
              IMAGE="${oci.imageName}:${oci.imageTag}"

              main() {
                # Load the image into the daemon
                ${oci.copyToDockerDaemon}/bin/copy-to-docker-daemon

                echo "=== DEEPCE escape detection: $IMAGE ==="
                echo ""

                # Run DEEPCE bind-mounted into the container.
                # busybox provides /bin/sh since hardened images may lack one.
                # --no-network: avoid external connections from CI
                # --no-colors: clean output for reports
                OUTPUT=$(podman run --rm \
                  -v "$BUSYBOX:/busybox:ro" \
                  -v "$DEEPCE:/deepce.sh:ro" \
                  --entrypoint /busybox \
                  "$IMAGE" \
                  sh /deepce.sh --no-network --no-colors 2>&1) || true

                echo "$OUTPUT"

                # Write report when CIMERA_REPORT_DIR is set
                if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                  mkdir -p "$CIMERA_REPORT_DIR"
                  echo "$OUTPUT" > "$CIMERA_REPORT_DIR/deepce-report.txt"
                fi

                # Fail on critical findings
                ISSUES=0

                if echo "$OUTPUT" | grep -qi "Docker Socket Found"; then
                  echo ""
                  echo "FAIL: Docker socket is exposed inside the container"
                  ISSUES=$((ISSUES + 1))
                fi

                if echo "$OUTPUT" | grep -qi "Privileged Mode"; then
                  echo ""
                  echo "FAIL: Container is running in privileged mode"
                  ISSUES=$((ISSUES + 1))
                fi

                echo ""
                if [ "$ISSUES" -gt 0 ]; then
                  echo "DEEPCE found $ISSUES critical issue(s)"
                  exit 1
                else
                  echo "DEEPCE: no critical escape vectors detected"
                fi
              }

              main "$@"
            '';
        };

        mkAppDeepce = {
          type = types.functionTo types.attrs;
          description = "Create flake app for DEEPCE container escape detection";
          file = "nix/modules/oci/testing/deepce/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptDeepce {
                  inherit perSystemConfig containerId;
                }
              }/bin/deepce-${containerId}";
            };
        };

        mkCheckDeepce = {
          type = types.functionTo types.package;
          description = "Run DEEPCE as a hermetic check via podman-in-sandbox";
          file = "nix/modules/oci/testing/deepce/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              deepce = perSystemConfig.packages.deepce;
              busybox = pkgs.pkgsStatic.busybox;
              dockerArchive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              imageRef = "localhost/${oci.imageName}:${oci.imageTag}";
            in
            ociLib.mkPodmanSandboxCheck {
              name = "deepce-${containerId}";
              inherit dockerArchive imageRef;
              testScript = ''
                OUTPUT=$(podman "''${PODMAN_FLAGS[@]}" run --rm \
                  -v "${busybox}/bin/busybox:/busybox:ro" \
                  -v "${deepce}/bin/deepce.sh:/deepce.sh:ro" \
                  --entrypoint /busybox \
                  "${imageRef}" \
                  sh /deepce.sh --no-network --no-colors 2>&1) || true

                echo "$OUTPUT"

                # Fail on Docker socket or privileged mode
                if echo "$OUTPUT" | grep -qi "Docker Socket Found"; then
                  echo "FAIL: Docker socket exposed" >&2
                  exit 1
                fi
                if echo "$OUTPUT" | grep -qi "Privileged Mode"; then
                  echo "FAIL: Privileged mode detected" >&2
                  exit 1
                fi
              '';
            };
        };
      };
    };
}
