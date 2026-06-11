# Privilege escalation auditing functions (linPEAS)
#
# linPEAS is a pure sh script — hardened images may not have a shell.
# We bind-mount both busybox (as the sh interpreter) and the script
# from the Nix store. The production image is never modified.
#
# By default runs with -q (quiet) -s (superfast) -N (no network)
# and checks only the "container" category to focus on container-
# specific privilege escalation vectors: SUID binaries, writable
# paths, capabilities, cgroup escapes, kernel exploits, etc.
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
        mkScriptLinpeas = {
          type = types.functionTo types.package;
          description = "Generate linPEAS privilege escalation auditing script";
          file = "nix/modules/oci/testing/linpeas/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              linpeas = perSystemConfig.packages.linpeas;
              busybox = pkgs.pkgsStatic.busybox;
            in
            pkgs.writeShellScriptBin "linpeas-${containerId}" ''
              set -o errexit
              set -o pipefail
              set -o nounset

              LINPEAS="${linpeas}/bin/linpeas.sh"
              BUSYBOX="${busybox}/bin/busybox"
              IMAGE="${oci.imageName}:${oci.imageTag}"

              main() {
                # Load the image into the daemon
                ${oci.copyToDockerDaemon}/bin/copy-to-docker-daemon

                echo "=== linPEAS privilege escalation audit: $IMAGE ==="
                echo ""

                # Run linPEAS bind-mounted into the container.
                # busybox provides /bin/sh since hardened images may lack one.
                # -q: quiet (no banner)
                # -s: superfast (skip slow checks)
                # -N: no network operations
                OUTPUT=$(podman run --rm \
                  -v "$BUSYBOX:/busybox:ro" \
                  -v "$LINPEAS:/linpeas.sh:ro" \
                  --entrypoint /busybox \
                  "$IMAGE" \
                  sh /linpeas.sh -q -s -N 2>&1) || true

                echo "$OUTPUT"

                # Write report when CIMERA_REPORT_DIR is set
                if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                  mkdir -p "$CIMERA_REPORT_DIR"
                  echo "$OUTPUT" > "$CIMERA_REPORT_DIR/linpeas-report.txt"
                fi

                # Check for critical findings (95% and 100% confidence markers)
                # linPEAS marks critical findings with red/yellow color codes.
                # In no-color mode, we look for specific patterns.
                ISSUES=0

                if echo "$OUTPUT" | grep -qi "docker.sock\|docker\.socket"; then
                  echo ""
                  echo "FAIL: Docker socket accessible inside container"
                  ISSUES=$((ISSUES + 1))
                fi

                if echo "$OUTPUT" | grep -qi "You are root"; then
                  echo ""
                  echo "WARN: Container process runs as root"
                fi

                echo ""
                if [ "$ISSUES" -gt 0 ]; then
                  echo "linPEAS found $ISSUES critical issue(s)"
                  exit 1
                else
                  echo "linPEAS: audit complete"
                fi
              }

              main "$@"
            '';
        };

        mkAppLinpeas = {
          type = types.functionTo types.attrs;
          description = "Create flake app for linPEAS privilege escalation auditing";
          file = "nix/modules/oci/testing/linpeas/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            {
              type = "app";
              program = "${
                ociLib.mkScriptLinpeas {
                  inherit perSystemConfig containerId;
                }
              }/bin/linpeas-${containerId}";
            };
        };

        mkCheckLinpeas = {
          type = types.functionTo types.package;
          description = "Run linPEAS as a hermetic check via podman-in-sandbox";
          file = "nix/modules/oci/testing/linpeas/lib.nix";
          fn =
            {
              perSystemConfig,
              containerId,
            }:
            let
              oci = perSystemConfig.internal.OCIs.${containerId};
              linpeas = perSystemConfig.packages.linpeas;
              busybox = pkgs.pkgsStatic.busybox;
              dockerArchive = ociLib.mkDockerArchive {
                inherit oci;
                inherit (perSystemConfig.packages) skopeo;
              };
              imageRef = "localhost/${oci.imageName}:${oci.imageTag}";
            in
            ociLib.mkPodmanSandboxCheck {
              name = "linpeas-${containerId}";
              inherit dockerArchive imageRef;
              testScript = ''
                OUTPUT=$(podman "''${PODMAN_FLAGS[@]}" run --rm \
                  -v "${busybox}/bin/busybox:/busybox:ro" \
                  -v "${linpeas}/bin/linpeas.sh:/linpeas.sh:ro" \
                  --entrypoint /busybox \
                  "${imageRef}" \
                  sh /linpeas.sh -q -s -N 2>&1) || true

                echo "$OUTPUT"

                # Fail on Docker socket access
                if echo "$OUTPUT" | grep -qi "docker.sock\|docker\.socket"; then
                  echo "FAIL: Docker socket accessible" >&2
                  exit 1
                fi
              '';
            };
        };
      };
    };
}
