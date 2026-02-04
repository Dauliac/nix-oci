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
                  DEST="oci:$OCI_DIR:$TEMP_TAG"
                  echo "Pushing temporary ${arch} image to OCI dir: $DEST..."
                  skopeo copy --insecure-policy \
                    nix:${ociOutput} \
                    "$DEST"
                else
                  FULL_NAME="''${CI_REGISTRY_IMAGE:-}${baseName}:$TEMP_TAG"
                  echo "Pushing temporary ${arch} image: $FULL_NAME..."
                  skopeo copy \
                    nix:${ociOutput} \
                    docker://"$FULL_NAME"
                fi
                echo "Successfully pushed ${arch} image"
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
                  FINAL_REF="$BASE_NAME:${primaryTag}"

                  REFS=""
                  for arch in ${lib.concatStringsSep " " arches}; do
                    TEMP_TAG="${containerConfig.multiArch.tempTagPrefix}-$arch-$COMMIT_SHA"
                    REFS="$REFS --ref $BASE_NAME:$TEMP_TAG --platform linux/$arch"
                  done

                  echo "Creating multi-arch manifest in OCI dir: $FINAL_REF..."
                  # shellcheck disable=SC2086
                  regctl index create "$FINAL_REF" $REFS
                  echo "Successfully created multi-arch manifest"

                  ${lib.concatMapStrings (tag: ''
                    echo "Copying to additional tag: ${tag}..."
                    regctl image copy "$BASE_NAME:${primaryTag}" "$BASE_NAME:${tag}"
                  '') additionalTags}

                  echo "Cleaning up temporary images..."
                  for arch in ${lib.concatStringsSep " " arches}; do
                    TEMP_TAG="${containerConfig.multiArch.tempTagPrefix}-$arch-$COMMIT_SHA"
                    echo "Deleting temporary tag: $TEMP_TAG..."
                    regctl tag delete "$BASE_NAME:$TEMP_TAG" || echo "Warning: Failed to delete $TEMP_TAG"
                  done
                else
                  BASE_NAME="''${CI_REGISTRY_IMAGE:-}${baseName}"
                  FINAL_REF="$BASE_NAME:${primaryTag}"

                  REFS=""
                  for arch in ${lib.concatStringsSep " " arches}; do
                    TEMP_TAG="${containerConfig.multiArch.tempTagPrefix}-$arch-$COMMIT_SHA"
                    REFS="$REFS --ref $BASE_NAME:$TEMP_TAG --platform linux/$arch"
                  done

                  echo "Creating multi-arch manifest for $FINAL_REF..."
                  # shellcheck disable=SC2086
                  regctl index create "$FINAL_REF" $REFS
                  echo "Successfully created multi-arch manifest"

                  ${lib.concatMapStrings (tag: ''
                    echo "Copying to additional tag: ${tag}..."
                    regctl image copy "$BASE_NAME:${primaryTag}" "$BASE_NAME:${tag}"
                  '') additionalTags}

                  echo "Cleaning up temporary images..."
                  for arch in ${lib.concatStringsSep " " arches}; do
                    TEMP_TAG="${containerConfig.multiArch.tempTagPrefix}-$arch-$COMMIT_SHA"
                    echo "Deleting temporary image: ${baseName}:$TEMP_TAG..."
                    regctl tag delete "$BASE_NAME:$TEMP_TAG" || echo "Warning: Failed to delete $TEMP_TAG"
                  done
                fi
                echo "Cleanup complete"
              '';
            };
        };
      };
    };
}
