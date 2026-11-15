# OCI mkPushApp -- build a writeShellApplication that pushes one
# specific tag of a built OCI image to the configured registry.
#
# Why per-tag: a push is the natural unit of parallelism. Emitting
# one derivation per tag lets consumers (nix-oci, other flakes)
# schedule pushes as independent Nix builds -- the executor fans them
# out automatically, failures are isolated per-tag, and retries
# become idempotent per-tag rather than all-or-nothing.
#
# Env contract (matches mkPushTempOCIApp / mkMergeMultiArchApp):
#   NIX_OCI_REGISTRY  → override configured registry
#   CI_REGISTRY_IMAGE    → GitLab-style registry prefix override
#   OCI_DIR              → if set, push to local ocidir:// instead
# Output contract:
#   "NIX_OCI_PUSHED_TAG ref=<full-ref> digest=<digest> tag=<tag> primary=<bool>"
#   For the primary tag additionally:
#   "NIX_OCI_PUSHED_DIGEST=<sha256:...>"        (consumed by oci-attach-referrer-substrate)
# fired on stdout -- downstream consumers grep for this marker.
{ lib, ... }:
let
  # Imported directly, not via `config.lib.oci`: a top-level nix-lib
  # registration populates the top-level lib, not perSystem's.
  pure = import ../../../lib/oci.nix { inherit lib; };
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
      nix-lib.lib.oci.mkPushApp = {
        type = lib.types.functionTo lib.types.package;
        description = ''
          Create an app that pushes a single tag of the built OCI
          image. One app per tag, one process per push -- parallel
          scheduling falls out for free.
        '';
        file = "nix/modules/oci/lib/mkPushApp.nix";
        fn =
          {
            perSystemConfig,
            containerId,
            tagConfig,
          }:
          let
            containerConfig = perSystemConfig.containers.${containerId};
            tag = tagConfig._tagName;
            ociOutput = perSystemConfig.internal.OCIs.${containerId};
            baseName = pure.mkRepoRef {
              inherit (containerConfig) registry name;
            };
            # The registry can also arrive at runtime via
            # NIX_OCI_REGISTRY / CI_REGISTRY_IMAGE, so the repository
            # path is lowercased separately for that branch.
            repoName = lib.strings.toLower containerConfig.name;
            appName = "push-${containerId}-${tag}";
            primaryLiteral = if tagConfig.primary then "true" else "false";
            # registry is types.nullOr types.str -- `or ""` does NOT handle null
            # (or only fires for missing attributes, not null values), so guard explicitly.
            registryFallback = if containerConfig.registry != null then containerConfig.registry else "";
            # Compression / SOCI flags and their invariants live in the
            # pure lib so all four push paths share one derivation.
            flags = pure.mkCompressionFlags {
              compression = containerConfig.performance.compression or "gzip";
              turbo = containerConfig.performance.turbo or { };
            };
            inherit (flags) compressFlag sociFlags;
            skopeoPackage =
              if flags.turboEnabled then
                perSystemConfig.packages.skopeoTurbo
              else
                perSystemConfig.packages.skopeo;
          in
          # Stays here: needs the package set, which the pure lib has no
          # access to.
          assert flags.turboEnabled -> perSystemConfig.packages.skopeoTurbo != null;
          pkgs.writeShellApplication {
            name = appName;
            runtimeInputs = [
              skopeoPackage
            ];
            text = ''
              REGISTRY="''${NIX_OCI_REGISTRY:-''${CI_REGISTRY_IMAGE:-${registryFallback}}}"

              if [ -n "''${OCI_DIR:-}" ]; then
                mkdir -p "$OCI_DIR"
                REF="$OCI_DIR:${tag}"
                DEST="oci:$REF"
              elif [ -n "$REGISTRY" ]; then
                REF="$REGISTRY/${repoName}:${tag}"
                DEST="docker://$REF"
              else
                echo "[${appName}] ERROR: no registry configured. Set NIX_OCI_REGISTRY or CI_REGISTRY_IMAGE, or set OCI_DIR for a local push." >&2
                exit 1
              fi

              # Digest-based skip: compare local image digest with remote tag.
              # If they match, the image is already pushed -- skip the expensive blob upload.
              LOCAL_DIGEST="$(skopeo inspect --format '{{.Digest}}' "nix:${ociOutput}" 2>/dev/null || echo "")"
              REMOTE_DIGEST="$(skopeo inspect --format '{{.Digest}}' "$DEST" 2>/dev/null || echo "")"

              if [ -n "$LOCAL_DIGEST" ] && [ "$LOCAL_DIGEST" = "$REMOTE_DIGEST" ]; then
                echo "[${appName}] image unchanged (digest=$LOCAL_DIGEST) -- skipping push"
                echo "NIX_OCI_PUSHED_TAG ref=$REF digest=$LOCAL_DIGEST tag=${tag} primary=${primaryLiteral}"
                ${lib.optionalString tagConfig.primary ''
                  echo "NIX_OCI_PUSHED_DIGEST=$LOCAL_DIGEST"
                ''}
              else
                echo "[${appName}] pushing ${containerId} -> $REF"

                skopeo copy --retry-times 3 ${compressFlag} ${sociFlags} \
                  "nix:${ociOutput}" "$DEST" >&2

                DIGEST="$(skopeo inspect --format '{{.Digest}}' "$DEST" 2>/dev/null || echo 'unknown')"

                echo "[${appName}] pushed $REF@$DIGEST"
                echo "NIX_OCI_PUSHED_TAG ref=$REF digest=$DIGEST tag=${tag} primary=${primaryLiteral}"
                ${lib.optionalString tagConfig.primary ''
                  echo "NIX_OCI_PUSHED_DIGEST=$DIGEST"
                ''}
              fi
            '';
          };
      };
    };
}
