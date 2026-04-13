# Multi-architecture OCI image functions
{
  lib,
  config,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) types;
  cfg = config;
in
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      nix-lib.lib.oci = {
        mkPushTempOCIApp = {
          type = types.functionTo types.package;
          description = "Create app to push image with architecture-specific temp tag for multi-arch builds";
          fn =
            {
              perSystemConfig,
              containerId,
              arch,
            }:
            let
              containerConfig = perSystemConfig.containers.${containerId};
              ociOutput = perSystemConfig.internal.OCIs.${containerId};
              tempTagPrefix = containerConfig.multiArch.tempTagPrefix;
              baseName =
                if containerConfig.registry != null && containerConfig.registry != "" then
                  "${containerConfig.registry}/${containerConfig.name}"
                else
                  containerConfig.name;
            in
            pkgs.writeShellApplication {
              name = "push-tmp-${containerId}";
              runtimeInputs = [
                perSystemConfig.packages.skopeo
                pkgs.git
              ];
              text = ''
                COMMIT_SHA="''${COMMIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}"
                TEMP_TAG="${tempTagPrefix}-${arch}-$COMMIT_SHA"

                if [ -n "''${OCI_DIR:-}" ]; then
                  mkdir -p "$OCI_DIR"
                  REF="$OCI_DIR:$TEMP_TAG"
                  DEST="oci:$REF"
                  echo "==> Pushing per-arch (${arch}) OCI image to local OCI dir"
                  echo "    source: nix:${ociOutput}"
                  echo "    target: $DEST"
                  skopeo copy --insecure-policy \
                    nix:${ociOutput} \
                    "$DEST"
                  DIGEST="$(skopeo inspect --format '{{.Digest}}' "$DEST" 2>/dev/null || echo 'unknown')"
                else
                  REF="''${CI_REGISTRY_IMAGE:-}${baseName}:$TEMP_TAG"
                  DEST="docker://$REF"
                  echo "==> Pushing per-arch (${arch}) OCI image"
                  echo "    source: nix:${ociOutput}"
                  echo "    target: $DEST"
                  skopeo copy \
                    nix:${ociOutput} \
                    "$DEST"
                  DIGEST="$(skopeo inspect --format '{{.Digest}}' "$DEST" 2>/dev/null || echo 'unknown')"
                fi
                echo "==> Pushed per-arch (${arch}) OCI image"
                echo "    image:  $REF"
                echo "    digest: $DIGEST"
                echo "CIMERA_OCI_PUSHED_TMP arch=${arch} ref=$REF digest=$DIGEST"
              '';
            };
        };

        mkMergeMultiArchApp = {
          type = types.functionTo types.package;
          description = "Create app to merge architecture-specific images into a multi-arch manifest list";
          fn =
            {
              perSystemConfig,
              containerId,
              systems,
            }:
            let
              containerConfig = perSystemConfig.containers.${containerId};
              archMap = {
                "x86_64-linux" = "amd64";
                "aarch64-linux" = "arm64";
              };
              baseName =
                if containerConfig.registry != null && containerConfig.registry != "" then
                  "${containerConfig.registry}/${containerConfig.name}"
                else
                  containerConfig.name;
              arches = builtins.map (sys: archMap.${sys}) systems;
              primaryTag = builtins.head containerConfig.tags;
              additionalTags = builtins.filter (tag: tag != primaryTag) containerConfig.tags;
            in
            pkgs.writeShellApplication {
              name = "merge-${containerId}";
              runtimeInputs = [
                perSystemConfig.packages.regctl
                pkgs.git
              ];
              text = ''
                COMMIT_SHA="''${COMMIT_SHA:-$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")}"

                if [ -n "''${OCI_DIR:-}" ]; then
                  BASE_NAME="ocidir://$OCI_DIR"
                  PRIMARY_REF="$BASE_NAME:${primaryTag}"
                else
                  BASE_NAME="''${CI_REGISTRY_IMAGE:-}${baseName}"
                  PRIMARY_REF="$BASE_NAME:${primaryTag}"
                fi

                REFS=""
                for arch in ${lib.concatStringsSep " " arches}; do
                  TEMP_TAG="${containerConfig.multiArch.tempTagPrefix}-$arch-$COMMIT_SHA"
                  REFS="$REFS --ref $BASE_NAME:$TEMP_TAG --platform linux/$arch"
                done

                echo "==> Creating multi-arch manifest"
                echo "    architectures: ${lib.concatStringsSep ", " arches}"
                echo "    target:        $PRIMARY_REF"
                # shellcheck disable=SC2086
                regctl index create "$PRIMARY_REF" $REFS

                # Resolve digest of the multi-arch index we just created.
                DIGEST="$(regctl manifest get --format '{{.GetDescriptor.Digest}}' "$PRIMARY_REF" 2>/dev/null || echo 'unknown')"

                echo "==> Published multi-arch OCI image"
                echo "    image:         $PRIMARY_REF"
                echo "    digest:        $DIGEST"
                echo "    architectures: ${lib.concatStringsSep ", " arches}"
                echo "CIMERA_OCI_PUBLISHED ref=$PRIMARY_REF digest=$DIGEST architectures=${lib.concatStringsSep "," arches}"

                ${lib.concatMapStrings (tag: ''
                  echo "==> Tagging additional: ${tag}"
                  regctl image copy "$PRIMARY_REF" "$BASE_NAME:${tag}"
                  echo "CIMERA_OCI_PUBLISHED ref=$BASE_NAME:${tag} digest=$DIGEST architectures=${lib.concatStringsSep "," arches}"
                '') additionalTags}

                echo "==> Cleaning up temporary per-arch tags"
                for arch in ${lib.concatStringsSep " " arches}; do
                  TEMP_TAG="${containerConfig.multiArch.tempTagPrefix}-$arch-$COMMIT_SHA"
                  regctl tag delete "$BASE_NAME:$TEMP_TAG" \
                    && echo "    deleted: $TEMP_TAG" \
                    || echo "    WARN: failed to delete $TEMP_TAG"
                done
              '';
            };
        };
      };
    };
}
