# Shared container probe infrastructure.
#
# Provides `mkContainerProbe` and `mkHermeticContainerProbe`, generic
# builders that inject an external tool into a running container via
# bind-mounts. Handles two cases:
#
#   1. Static binary (e.g. amicontained) — bind-mount the binary
#      directly and use it as entrypoint.
#
#   2. Shell script (e.g. DEEPCE, linPEAS) — bind-mount both a
#      static busybox (providing /bin/sh) and the script. busybox
#      becomes the entrypoint, executing the script as `sh <script>`.
#
# In both cases, the production image is never modified. The tool
# lives in the Nix store and is mounted read-only.
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
      busybox = pkgs.pkgsStatic.busybox;
    in
    {
      nix-lib.lib.oci = {
        # ── Non-hermetic probe (needs a running podman/docker daemon) ──

        mkContainerProbe = {
          type = types.functionTo types.package;
          description = ''
            Run an external tool inside a container via bind-mount.

            For static binaries: mounts the binary and uses it as entrypoint.
            For shell scripts: mounts busybox + script, uses busybox sh as entrypoint.

            The production image is never modified.
          '';
          file = "nix/modules/oci/testing/container-probe/lib.nix";
          fn =
            {
              # Script/app name used for the wrapper derivation
              name,
              # The OCI image (from perSystemConfig.internal.OCIs)
              oci,
              # Path to the tool binary or script in the Nix store
              probe,
              # Arguments passed to the probe
              args ? "",
              # If true, inject busybox as /bin/sh for script execution
              needsShell ? false,
              # Report file name (written under CIMERA_REPORT_DIR)
              reportName ? "${name}-report.txt",
              # Grep patterns that cause a hard failure (exit 1).
              # Each entry: { pattern = "regex"; message = "human text"; }
              failPatterns ? [ ],
              # Grep patterns that emit a warning but don't fail.
              warnPatterns ? [ ],
            }:
            let
              volumeFlags =
                if needsShell then
                  ''-v "${busybox}/bin/busybox:/busybox:ro" -v "${probe}:/probe.sh:ro"''
                else
                  ''-v "${probe}:/probe:ro"'';

              entrypointAndArgs =
                if needsShell then
                  ''--entrypoint /busybox "$IMAGE" sh /probe.sh ${args}''
                else
                  ''--entrypoint /probe "$IMAGE" ${args}'';

              failChecks = lib.concatMapStringsSep "\n" (f: ''
                if echo "$OUTPUT" | grep -qi ${lib.escapeShellArg f.pattern}; then
                  echo ""
                  echo "FAIL: ${f.message}"
                  ISSUES=$((ISSUES + 1))
                fi
              '') failPatterns;

              warnChecks = lib.concatMapStringsSep "\n" (w: ''
                if echo "$OUTPUT" | grep -qi ${lib.escapeShellArg w.pattern}; then
                  echo ""
                  echo "WARN: ${w.message}"
                fi
              '') warnPatterns;
            in
            pkgs.writeShellScriptBin name ''
              set -o errexit
              set -o pipefail
              set -o nounset

              IMAGE="${oci.imageName}:${oci.imageTag}"

              main() {
                ${oci.copyToDockerDaemon}/bin/copy-to-docker-daemon

                echo "=== ${name}: $IMAGE ==="
                echo ""

                OUTPUT=$(podman run --rm \
                  ${volumeFlags} \
                  ${entrypointAndArgs} 2>&1) || true

                echo "$OUTPUT"

                # Write report when CIMERA_REPORT_DIR is set
                if [ -n "''${CIMERA_REPORT_DIR:-}" ]; then
                  mkdir -p "$CIMERA_REPORT_DIR"
                  echo "$OUTPUT" > "$CIMERA_REPORT_DIR/${reportName}"
                fi

                ISSUES=0
                ${failChecks}
                ${warnChecks}

                echo ""
                if [ "$ISSUES" -gt 0 ]; then
                  echo "${name} found $ISSUES critical issue(s)"
                  exit 1
                else
                  echo "${name}: no critical issues detected"
                fi
              }

              main "$@"
            '';
        };

        # ── Hermetic probe (runs inside Nix build sandbox) ─────────────

        mkHermeticContainerProbe = {
          type = types.functionTo types.package;
          description = ''
            Run an external tool inside a container via bind-mount,
            hermetically inside the Nix build sandbox using podman.
          '';
          file = "nix/modules/oci/testing/container-probe/lib.nix";
          fn =
            {
              name,
              dockerArchive,
              imageRef,
              probe,
              args ? "",
              needsShell ? false,
              failPatterns ? [ ],
            }:
            let
              volumeFlags =
                if needsShell then
                  ''-v "${busybox}/bin/busybox:/busybox:ro" -v "${probe}:/probe.sh:ro"''
                else
                  ''-v "${probe}:/probe:ro"'';

              entrypointAndArgs =
                if needsShell then
                  ''--entrypoint /busybox "${imageRef}" sh /probe.sh ${args}''
                else
                  ''--entrypoint /probe "${imageRef}" ${args}'';

              failChecks = lib.concatMapStringsSep "\n" (f: ''
                if echo "$OUTPUT" | grep -qi ${lib.escapeShellArg f.pattern}; then
                  echo "FAIL: ${f.message}" >&2
                  exit 1
                fi
              '') failPatterns;
            in
            ociLib.mkPodmanSandboxCheck {
              inherit name dockerArchive imageRef;
              testScript = ''
                OUTPUT=$(podman "''${PODMAN_FLAGS[@]}" run --rm \
                  ${volumeFlags} \
                  ${entrypointAndArgs} 2>&1) || true

                echo "$OUTPUT"
                ${failChecks}
              '';
            };
        };
      };
    };
}
