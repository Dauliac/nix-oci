# OCI apps intermediate output.
#
# 4 apps per container:
#   oci-sandbox-<name>       — bubblewrap shell in the container
#   oci-push-<name>          — push to registry (gated)
#   oci-load-docker-<name>   — load into Docker (gated)
#   oci-load-podman-<name>   — load into Podman (gated)
#
# Plus multi-arch helpers when enabled.
{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    any
    attrValues
    ;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, ... }:
    {
      options.oci.flake.apps = mkOption {
        type = types.attrsOf types.attrs;
        description = "OCI-related apps that can be exposed as flake outputs.";
        readOnly = true;
        defaultText = lib.literalMD "Per-container `sandbox`, `push`, `load-docker`, `load-podman` apps.";
        default =
          let
            hasExternalDependencies = any (containerConfig: containerConfig.fromImage.enabled) (
              attrValues config.oci.containers
            );
            updateManifestApp =
              if hasExternalDependencies then
                {
                  oci-update-manifests = {
                    type = "app";
                    program = lib.getExe config.oci.internal.updatepulledOCIsManifestLocks;
                  };
                }
              else
                { };
          in
          updateManifestApp
          // config.oci.pipeline.apps
          // config.oci.internal.prefixedPushTmpOCIApps
          // config.oci.internal.prefixedMergeMultiArchApps;
      };
    }
  );
}
