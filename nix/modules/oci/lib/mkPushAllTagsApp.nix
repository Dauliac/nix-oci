# OCI mkPushAllTagsApp -- push one image with all its tags efficiently.
#
# Instead of N independent `skopeo copy nix:→docker://` calls (which
# each re-upload every blob), this pushes the primary tag once from the
# Nix store, then creates additional tags via registry-side copies
# (`skopeo copy docker://→docker://`).  Registry-side copies transfer
# zero blobs -- they just create a new manifest pointing to existing
# layers.
#
# For a container with 3 tags (latest, sha, branch) this reduces
# network transfer from 3× to 1×.
#
# Env contract (same as mkPushApp):
#   CIMERA_OCI_REGISTRY  → override configured registry
#   CI_REGISTRY_IMAGE    → GitLab-style registry prefix override
#   OCI_DIR              → if set, push to local ocidir:// instead
# Output contract:
#   "CIMERA_OCI_PUSHED_TAG ref=<full-ref> digest=<digest> tag=<tag> primary=<bool>"
#   emitted on stdout for each tag -- downstream consumers grep for this.
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      nix-lib.lib.oci.mkPushAllTagsApp = {
        type = lib.types.functionTo lib.types.package;
        description = ''
          Create an app that pushes all tags of a built OCI image
          efficiently: one real push for the primary tag, then
          registry-side copies for additional tags.
        '';
        file = "nix/modules/oci/lib/mkPushAllTagsApp.nix";
        fn =
          {
            perSystemConfig,
            containerId,
          }:
          let
            containerConfig = perSystemConfig.containers.${containerId};
            tagConfigs = containerConfig.tagConfigs;
            tagNames = lib.attrNames tagConfigs;

            primaryTag = lib.findFirst (t: tagConfigs.${t}.primary) (builtins.head tagNames) tagNames;

            additionalTags = lib.filter (t: t != primaryTag) tagNames;

            ociOutput = perSystemConfig.internal.OCIs.${containerId};

            baseName =
              if containerConfig.registry != null && containerConfig.registry != "" then
                "${containerConfig.registry}/${containerConfig.name}"
              else
                containerConfig.name;

            appName = "push-all-${containerId}";

            registryFallback = if containerConfig.registry != null then containerConfig.registry else "";

            compression = containerConfig.performance.compression or "gzip";
            compressFlag = if compression == "zstd" then "--dest-compress-format zstd" else "";

            mkAdditionalTagScript = tag: ''
              # Check if this additional tag already points to the correct digest.
              EXTRA_REMOTE="$(skopeo inspect --format '{{.Digest}}' \
                "''${DEST_PREFIX}${tag}" 2>/dev/null || echo "")"
              if [ -n "$LOCAL_DIGEST" ] && [ "$EXTRA_REMOTE" = "$LOCAL_DIGEST" ]; then
                echo "[${appName}] tag ${tag} already correct (digest=$LOCAL_DIGEST) -- skipping"
                echo "CIMERA_OCI_PUSHED_TAG ref=''${BASE_REF}:${tag} digest=$LOCAL_DIGEST tag=${tag} primary=false"
              else
                echo "[${appName}] tagging ${containerId}: ${primaryTag} -> ${tag} (registry-side copy)"
                skopeo copy --retry-times 3 \
                  "''${PRIMARY_DEST}" "''${DEST_PREFIX}${tag}" >&2
                EXTRA_DIGEST="$(skopeo inspect --format '{{.Digest}}' \
                  "''${DEST_PREFIX}${tag}" 2>/dev/null || echo 'unknown')"
                echo "[${appName}] tagged ''${BASE_REF}:${tag}@$EXTRA_DIGEST"
                echo "CIMERA_OCI_PUSHED_TAG ref=''${BASE_REF}:${tag} digest=$EXTRA_DIGEST tag=${tag} primary=false"
              fi
            '';
          in
          pkgs.writeShellApplication {
            name = appName;
            runtimeInputs = [
              perSystemConfig.packages.skopeo
            ];
            text = ''
              REGISTRY="''${CIMERA_OCI_REGISTRY:-''${CI_REGISTRY_IMAGE:-${registryFallback}}}"

              if [ -n "''${OCI_DIR:-}" ]; then
                mkdir -p "$OCI_DIR"
                BASE_REF="$OCI_DIR"
                PRIMARY_DEST="oci:$OCI_DIR:${primaryTag}"
                DEST_PREFIX="oci:$OCI_DIR:"
              elif [ -n "$REGISTRY" ]; then
                BASE_REF="$REGISTRY/${containerConfig.name}"
                PRIMARY_DEST="docker://$BASE_REF:${primaryTag}"
                DEST_PREFIX="docker://$BASE_REF:"
              else
                echo "[${appName}] ERROR: no registry configured. Set CIMERA_OCI_REGISTRY or CI_REGISTRY_IMAGE, or set OCI_DIR for a local push." >&2
                exit 1
              fi

              # Digest-based skip: compare local image digest with remote primary tag.
              LOCAL_DIGEST="$(skopeo inspect --format '{{.Digest}}' "nix:${ociOutput}" 2>/dev/null || echo "")"
              PRIMARY_REMOTE="$(skopeo inspect --format '{{.Digest}}' "$PRIMARY_DEST" 2>/dev/null || echo "")"

              # Step 1: Push primary tag (skip if remote already has the same digest).
              if [ -n "$LOCAL_DIGEST" ] && [ "$LOCAL_DIGEST" = "$PRIMARY_REMOTE" ]; then
                echo "[${appName}] primary tag ${primaryTag} unchanged (digest=$LOCAL_DIGEST) -- skipping blob upload"
                DIGEST="$LOCAL_DIGEST"
                echo "CIMERA_OCI_PUSHED_TAG ref=$BASE_REF:${primaryTag} digest=$DIGEST tag=${primaryTag} primary=true"
              else
                echo "[${appName}] pushing ${containerId}: ${primaryTag} -> $BASE_REF:${primaryTag}"
                skopeo copy --retry-times 3 ${compressFlag} \
                  "nix:${ociOutput}" "$PRIMARY_DEST" >&2
                DIGEST="$(skopeo inspect --format '{{.Digest}}' \
                  "$PRIMARY_DEST" 2>/dev/null || echo 'unknown')"
                echo "[${appName}] pushed $BASE_REF:${primaryTag}@$DIGEST"
                echo "CIMERA_OCI_PUSHED_TAG ref=$BASE_REF:${primaryTag} digest=$DIGEST tag=${primaryTag} primary=true"
              fi

              # Step 2: Create additional tags via registry-side copy (skip if already correct).
              ${lib.concatMapStrings mkAdditionalTagScript additionalTags}

              echo "[${appName}] all ${
                toString (1 + lib.length additionalTags)
              } tag(s) processed for ${containerId}"
            '';
          };
      };
    };
}
