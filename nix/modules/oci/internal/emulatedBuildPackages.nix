# Internal options for QEMU-emulated multi-arch OCI images
#
# Mirrors crossBuildPackages.nix but filters for emulatedBuild.enable.
# Reuses the same nix-lib functions (mkCrossOCI, mkMultiArchOCILayout,
# mkPushOCILayoutApp) -- those functions are package-source-agnostic.
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
          emulatedOCIs = mkOption {
            description = "QEMU-emulated per-arch OCI images for multi-arch containers.";
            type = types.attrsOf (types.attrsOf types.package);
            internal = true;
            readOnly = true;
            default =
              let
                emulatedContainers = attrsets.filterAttrs (
                  _: c: c.multiArch.enabled && c.multiArch.emulatedBuild.enable
                ) config.oci.containers;
                # Mutual exclusion: fail if any emulated container also has crossBuild
                conflicting = attrsets.filterAttrs (_: c: c.multiArch.crossBuild.enable) emulatedContainers;
                conflictNames = builtins.attrNames conflicting;
              in
              assert
                conflictNames == [ ]
                || throw ''
                  Containers ${builtins.concatStringsSep ", " (map (n: "\"${n}\"") conflictNames)}:
                  `multiArch.crossBuild.enable` and `multiArch.emulatedBuild.enable` are mutually exclusive.
                  Choose one build strategy per container:
                    - crossBuild:    fast, uses pkgsCross (some packages may not cross-compile)
                    - emulatedBuild: slower, uses QEMU binfmt (works for any natively-buildable package)
                '';
              attrsets.mapAttrs (
                containerId: containerConfig:
                let
                  emulatedArchConfigs = attrsets.filterAttrs (
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
                ) emulatedArchConfigs
              ) emulatedContainers;
          };
          emulatedMultiArchOCILayouts = mkOption {
            description = "Merged multi-arch OCI directory layouts (native + QEMU-emulated).";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default =
              if !(ociLib.archMap ? ${system}) then
                { }
              else
                lib.pipe config.oci.containers [
                  (attrsets.filterAttrs (_: c: c.multiArch.enabled && c.multiArch.emulatedBuild.enable))
                  (attrsets.mapAttrs (
                    containerId: _:
                    let
                      nativeArch = ociLib.systemToOCIArch system;
                      nativeImage = config.oci.internal.OCIs.${containerId};
                      emulatedImages = config.oci.internal.emulatedOCIs.${containerId};
                      allImages = {
                        ${nativeArch} = nativeImage;
                      }
                      // emulatedImages;
                    in
                    ociLib.mkMultiArchOCILayout {
                      perSystemConfig = config.oci;
                      inherit containerId;
                      images = allImages;
                    }
                  ))
                ];
          };
          prefixedEmulatedMultiArchOCILayouts = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs' (
              name: layout: attrsets.nameValuePair "oci-multiarch-${name}" layout
            ) config.oci.internal.emulatedMultiArchOCILayouts;
          };
          pushEmulatedMultiArchLayoutApps = mkOption {
            description = "Apps to push QEMU-emulated multi-arch OCI layouts to a registry.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: layout:
              ociLib.mkPushOCILayoutApp {
                perSystemConfig = config.oci;
                inherit containerId layout;
              }
            ) config.oci.internal.emulatedMultiArchOCILayouts;
          };
          prefixedPushEmulatedMultiArchLayoutApps = mkOption {
            type = types.attrsOf types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs' (
              name: app:
              attrsets.nameValuePair "oci-push-multiarch-${name}" {
                type = "app";
                program = lib.getExe app;
              }
            ) config.oci.internal.pushEmulatedMultiArchLayoutApps;
          };
        };
      }
    );
  };
}
