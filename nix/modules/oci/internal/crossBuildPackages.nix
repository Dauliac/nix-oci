# Internal options for cross-build multi-arch OCI images
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  cfg = config;
  inherit (lib)
    mkOption
    types
    attrsets
    ;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      {
        config,
        pkgs,
        system,
        ...
      }:
      let
        ociLib = config.lib.oci or { };
      in
      {
        options.oci.internal = {
          crossOCIs = mkOption {
            description = "Cross-compiled per-arch OCI images for multi-arch containers.";
            type = types.attrsOf (types.attrsOf types.package);
            internal = true;
            readOnly = true;
            default = lib.pipe config.oci.containers [
              (attrsets.filterAttrs (_: c: c.multiArch.enabled && c.multiArch.crossBuild.enable))
              (attrsets.mapAttrs (
                containerId: containerConfig:
                let
                  # Filter archConfigs to only non-native arches with a package set
                  crossArchConfigs = attrsets.filterAttrs (
                    targetSystem: archCfg: targetSystem != system && archCfg.package != null
                  ) containerConfig.archConfigs;
                in
                attrsets.mapAttrs (
                  targetSystem: archCfg:
                  ociLib.mkCrossOCI {
                    perSystemConfig = config.oci;
                    globalConfig = cfg.oci;
                    inherit containerId;
                    crossPackage = archCfg.package;
                    crossDependencies = archCfg.dependencies;
                    arch = ociLib.systemToOCIArch targetSystem;
                  }
                ) crossArchConfigs
              ))
            ];
          };
          multiArchOCILayouts = mkOption {
            description = "Merged multi-arch OCI directory layouts (native + cross-compiled).";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default =
              if !(ociLib.archMap ? ${system}) then
                { }
              else
                lib.pipe config.oci.containers [
                  (attrsets.filterAttrs (_: c: c.multiArch.enabled && c.multiArch.crossBuild.enable))
                  (attrsets.mapAttrs (
                    containerId: _:
                    let
                      nativeArch = ociLib.systemToOCIArch system;
                      nativeImage = config.oci.internal.OCIs.${containerId};
                      crossImages = config.oci.internal.crossOCIs.${containerId};
                      allImages = {
                        ${nativeArch} = nativeImage;
                      }
                      // crossImages;
                    in
                    ociLib.mkMultiArchOCILayout {
                      perSystemConfig = config.oci;
                      inherit containerId;
                      images = allImages;
                    }
                  ))
                ];
          };
          prefixedMultiArchOCILayouts = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs' (
              name: layout: attrsets.nameValuePair "oci-multiarch-${name}" layout
            ) config.oci.internal.multiArchOCILayouts;
          };
          pushMultiArchLayoutApps = mkOption {
            description = "Apps to push cross-built multi-arch OCI layouts to a registry.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: layout:
              ociLib.mkPushOCILayoutApp {
                perSystemConfig = config.oci;
                inherit containerId layout;
              }
            ) config.oci.internal.multiArchOCILayouts;
          };
          prefixedPushMultiArchLayoutApps = mkOption {
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs' (
              name: app:
              attrsets.nameValuePair "oci-push-multiarch-${name}" {
                type = "app";
                program = lib.getExe app;
              }
            ) config.oci.internal.pushMultiArchLayoutApps;
          };
        };
      }
    );
  };
}
