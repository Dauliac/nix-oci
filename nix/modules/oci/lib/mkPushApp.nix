# OCI mkPushApp — build a writeShellApplication that pushes one
# specific tag of a built OCI image to the configured registry.
#
# Why per-tag: a push is the natural unit of parallelism. Emitting
# one derivation per tag lets consumers (cimera, other flakes)
# schedule pushes as independent Nix builds — the executor fans them
# out automatically, failures are isolated per-tag, and retries
# become idempotent per-tag rather than all-or-nothing.
#
# Env contract (matches mkPushTempOCIApp / mkMergeMultiArchApp):
#   CIMERA_OCI_REGISTRY  → override configured registry
#   CI_REGISTRY_IMAGE    → GitLab-style registry prefix override
#   OCI_DIR              → if set, push to local ocidir:// instead
# Output contract:
#   "CIMERA_OCI_PUSHED_TAG ref=<full-ref> digest=<digest> tag=<tag> primary=<bool>"
# fired on stdout — downstream consumers grep for this marker.
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
      nix-lib.lib.oci.mkPushApp = {
        type = lib.types.functionTo lib.types.package;
        description = ''
          Create an app that pushes a single tag of the built OCI
          image. One app per tag, one process per push — parallel
          scheduling falls out for free.
        '';
        fn =
          {
            perSystemConfig,
            containerId,
            tagConfig,
            # When true, pushes the debug image variant and appends
            # "-debug" to the tag literal (e.g. "1.0.0" → "1.0.0-debug").
            debug ? false,
          }:
          let
            containerConfig = perSystemConfig.containers.${containerId};
            tag = if debug then "${tagConfig._tagName}-debug" else tagConfig._tagName;
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
            appName = if debug then "push-debug-${containerId}-${tag}" else "push-${containerId}-${tag}";
            primaryLiteral = if tagConfig.primary then "true" else "false";
            # registry is types.nullOr types.str — `or ""` does NOT handle null
            # (or only fires for missing attributes, not null values), so guard explicitly.
            registryFallback = if containerConfig.registry != null then containerConfig.registry else "";
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
                REF="$OCI_DIR:${tag}"
                DEST="oci:$REF"
              elif [ -n "$REGISTRY" ]; then
                REF="$REGISTRY/${containerConfig.name}:${tag}"
                DEST="docker://$REF"
              else
                echo "[${appName}] ERROR: no registry configured. Set CIMERA_OCI_REGISTRY or CI_REGISTRY_IMAGE, or set OCI_DIR for a local push." >&2
                exit 1
              fi

              echo "[${appName}] pushing ${containerId}${lib.optionalString debug " (debug)"} -> $REF"

              skopeo copy --retry-times 3 \
                "nix:${ociOutput}" "$DEST" >&2

              DIGEST="$(skopeo inspect --format '{{.Digest}}' "$DEST" 2>/dev/null || echo 'unknown')"

              echo "[${appName}] pushed $REF@$DIGEST"
              echo "CIMERA_OCI_PUSHED_TAG ref=$REF digest=$DIGEST tag=${tag} primary=${primaryLiteral}"
            '';
          };
      };
    };
}
