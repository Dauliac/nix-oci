# OCI mkPushAllTagsApp — push one image with all its tags efficiently.
#
# Instead of N independent `skopeo copy nix:→docker://` calls (which
# each re-upload every blob), this pushes the primary tag once from the
# Nix store, then creates additional tags via registry-side copies
# (`skopeo copy docker://→docker://`).  Registry-side copies transfer
# zero blobs — they just create a new manifest pointing to existing
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
#   emitted on stdout for each tag — downstream consumers grep for this.
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
        fn =
          {
            perSystemConfig,
            containerId,
            debug ? false,
          }:
          let
            containerConfig = perSystemConfig.containers.${containerId};
            tagConfigs = containerConfig.tagConfigs;
            tagNames = lib.attrNames tagConfigs;

            # Find the primary tag (first in the tags list).
            primaryTag =
              let
                primary = lib.findFirst
                  (t: tagConfigs.${t}.primary)
                  (builtins.head tagNames)
                  tagNames;
              in
                if debug then "${primary}-debug" else primary;

            additionalTags = lib.filter (t:
              let tag = if debug then "${t}-debug" else t;
              in tag != primaryTag
            ) tagNames;

            ociOutput =
              if debug then
                perSystemConfig.internal.debugOCIs."${containerId}-debug"
              else
                perSystemConfig.internal.OCIs.${containerId};

            baseName =
              if containerConfig.registry != null && containerConfig.registry != "" then
                "${containerConfig.registry}/${containerConfig.name}"
              else
                containerConfig.name;

            appName =
              if debug
              then "push-all-debug-${containerId}"
              else "push-all-${containerId}";

            registryFallback =
              if containerConfig.registry != null
              then containerConfig.registry
              else "";

            mkAdditionalTagScript = tag: let
              effectiveTag = if debug then "${tag}-debug" else tag;
            in ''
              echo "[${appName}] tagging ${containerId}: ${primaryTag} -> ${effectiveTag} (registry-side copy)"
              skopeo copy --retry-times 3 \
                "''${PRIMARY_DEST}" "''${DEST_PREFIX}${effectiveTag}" >&2
              EXTRA_DIGEST="$(skopeo inspect --format '{{.Digest}}' \
                "''${DEST_PREFIX}${effectiveTag}" 2>/dev/null || echo 'unknown')"
              echo "[${appName}] tagged ''${BASE_REF}:${effectiveTag}@$EXTRA_DIGEST"
              echo "CIMERA_OCI_PUSHED_TAG ref=''${BASE_REF}:${effectiveTag} digest=$EXTRA_DIGEST tag=${effectiveTag} primary=false"
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

              # Step 1: Push primary tag (the only real blob transfer).
              echo "[${appName}] pushing ${containerId}${lib.optionalString debug " (debug)"}: ${primaryTag} -> $BASE_REF:${primaryTag}"
              skopeo copy --retry-times 3 \
                "nix:${ociOutput}" "$PRIMARY_DEST" >&2
              DIGEST="$(skopeo inspect --format '{{.Digest}}' \
                "$PRIMARY_DEST" 2>/dev/null || echo 'unknown')"
              echo "[${appName}] pushed $BASE_REF:${primaryTag}@$DIGEST"
              echo "CIMERA_OCI_PUSHED_TAG ref=$BASE_REF:${primaryTag} digest=$DIGEST tag=${primaryTag} primary=true"

              # Step 2: Create additional tags via registry-side copy (zero blob transfer).
              ${lib.concatMapStrings mkAdditionalTagScript additionalTags}

              echo "[${appName}] all ${toString (1 + lib.length additionalTags)} tag(s) pushed for ${containerId}"
            '';
          };
      };
    };
}
