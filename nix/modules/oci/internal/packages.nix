{
  config,
  lib,
  self,
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
  archMap = {
    "x86_64-linux" = "amd64";
    "aarch64-linux" = "arm64";
  };
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
          pulledOCIs = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default =
              attrsets.mapAttrs
                (
                  containerId: containerConfig:
                  ociLib.mkOCIPulledManifestLock {
                    perSystemConfig = config.oci;
                    globalConfig = cfg.oci;
                    inherit containerId;
                  }
                )
                (
                  attrsets.filterAttrs (_: containerConfig: containerConfig.fromImage.enabled) config.oci.containers
                );
          };
          OCIs = mkOption {
            description = "Built OCI container images.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: containerConfig:
              ociLib.mkOCI {
                perSystemConfig = config.oci;
                globalConfig = cfg.oci;
                inherit containerId;
              }
            ) config.oci.containers;
          };
          debugOCIs = mkOption {
            description = "Built debug OCI container images.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = lib.pipe config.oci.internal.OCIs [
              (attrsets.mapAttrs' (
                containerId: ociOutput:
                let
                  containerConfig = config.oci.containers.${containerId};
                in
                if containerConfig.debug.enabled && ociOutput ? debug then
                  attrsets.nameValuePair "${containerId}-debug" ociOutput.debug
                else
                  attrsets.nameValuePair "${containerId}-debug-disabled" null
              ))
              (attrsets.filterAttrs (_: v: v != null))
            ];
          };
          prefixedOCIs = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.prefixOutputs {
              prefix = "oci-";
              set = config.oci.internal.OCIs // config.oci.internal.debugOCIs;
            };
          };
          updatepulledOCIsManifestLocks = mkOption {
            type = types.package;
            internal = true;
            readOnly = true;
            default = ociLib.mkOCIPulledManifestLockUpdateScript {
              inherit self;
              perSystemConfig = config.oci;
              globalConfig = cfg.oci;
            };
          };
          pushTmpOCIApps = mkOption {
            description = "Apps to push architecture-specific temporary images for multi-arch builds. Keyed by containerId-arch.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default =
              let
                arch = archMap.${system} or null;
              in
              if arch == null then
                { }
              else
                lib.pipe config.oci.containers [
                  (attrsets.filterAttrs (_: c: c.multiArch.enabled))
                  (attrsets.mapAttrs' (
                    containerId: containerConfig:
                    # Include arch in the key for explicit naming
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
              # name is already containerId-arch
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
                    systems = cfg.systems;
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
