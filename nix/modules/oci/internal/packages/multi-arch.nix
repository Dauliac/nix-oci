{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  cfg = config;
  inherit (lib) mkOption types attrsets;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      {
        config,
        system,
        ...
      }:
      let
        ociLib = config.lib.oci or { };
      in
      {
        options.oci.internal = {
          pushTmpOCIApps = mkOption {
            description = "Apps to push architecture-specific temporary images for multi-arch builds. Keyed by containerId-arch.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default =
              let
                arch = if ociLib.archMap ? ${system} then ociLib.systemToOCIArch system else null;
              in
              if arch == null then
                { }
              else
                lib.pipe config.oci.containers [
                  (attrsets.filterAttrs (_: c: c.multiArch.enabled))
                  (attrsets.mapAttrs' (
                    containerId: containerConfig:
                    attrsets.nameValuePair "${containerId}-${arch}" (
                      ociLib.mkPushTempOCIApp {
                        perSystemConfig = config.oci;
                        inherit containerId arch;
                      }
                    )
                  ))
                ];
          };
          prefixedPushTmpOCIApps = mkOption {
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs' (
              name: app:
              attrsets.nameValuePair "oci-push-tmp-${name}" {
                type = "app";
                program = lib.getExe app;
              }
            ) config.oci.internal.pushTmpOCIApps;
          };
          mergeMultiArchApps = mkOption {
            description = "Apps to merge architecture-specific images into multi-arch manifest lists.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = lib.pipe config.oci.containers [
              (attrsets.filterAttrs (_: c: c.multiArch.enabled))
              (attrsets.mapAttrs' (
                containerId: containerConfig:
                attrsets.nameValuePair containerId (
                  ociLib.mkMergeMultiArchApp {
                    perSystemConfig = config.oci;
                    inherit containerId;
                    systems = containerConfig.multiArch.systems;
                  }
                )
              ))
            ];
          };
          prefixedMergeMultiArchApps = mkOption {
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs' (
              name: app:
              attrsets.nameValuePair "oci-merge-${name}" {
                type = "app";
                program = lib.getExe app;
              }
            ) config.oci.internal.mergeMultiArchApps;
          };
        };
      }
    );
  };
}
