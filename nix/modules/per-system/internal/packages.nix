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
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      {
        config,
        pkgs,
        ...
      }:
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
                  cfg.oci.lib.mkOCIPulledManifestLock {
                    config = cfg.oci;
                    inherit containerId;
                    perSystemConfig = config.oci;
                  }
                )
                (
                  attrsets.filterAttrs (_: containerConfig: containerConfig.fromImage != null) config.oci.containers
                );
          };
          OCIs = mkOption {
            description = "Built OCI container images.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: containerConfig:
              cfg.oci.lib.mkOCI {
                inherit pkgs;
                inherit containerId;
                config = cfg.oci;
                perSystemConfig = config.oci;
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
            default = cfg.oci.lib.prefixOutputs {
              prefix = "oci-";
              set = config.oci.internal.OCIs // config.oci.internal.debugOCIs;
            };
          };
          updatepulledOCIsManifestLocks = mkOption {
            type = types.package;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.mkOCIPulledManifestLockUpdateScript {
              inherit
                pkgs
                self
                ;
              config = cfg.oci;
              perSystemConfig = config.oci;
            };
          };
        };
      }
    );
  };
}
