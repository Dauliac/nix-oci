{
  lib,
  self,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mkOption types attrsets;
in
{
  options = {
    perSystem = flake-parts-lib.mkPerSystemOption (
      { config, ... }:
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
                    inherit containerId;
                  }
                )
                (
                  attrsets.filterAttrs (_: containerConfig: containerConfig.fromImage.enabled) config.oci.containers
                );
          };
          updatepulledOCIsManifestLocks = mkOption {
            type = types.package;
            internal = true;
            readOnly = true;
            default = ociLib.mkOCIPulledManifestLockUpdateScript {
              inherit self;
              perSystemConfig = config.oci;
            };
          };
        };
      }
    );
  };
}
