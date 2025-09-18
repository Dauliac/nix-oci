localflake:
{
  config,
  lib,
  self,
  flake-parts-lib,
  ...
}:
let
  localLib = localflake.config.lib;
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
                  localLib.mkOCIPulledManifestLock {
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
            type = types.attrsOf types.package;
            default = attrsets.mapAttrs (
              containerId: containerConfig:
              localLib.mkOCI {
                inherit pkgs;
                inherit containerId;
                config = cfg.oci;
                perSystemConfig = config.oci;
              }
            ) config.oci.containers;
          };
          prefixedOCIs = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = localLib.prefixOutputs {
              prefix = "oci-";
              set = config.oci.internal.OCIs;
            };
          };
          allOCIs = mkOption {
            type = types.package;
            internal = true;
            readOnly = true;
            default =
              pkgs.runCommand "oci-all"
                {
                  buildInputs = [ ];
                }
                ''
                  mkdir -p $out
                  ${lib.concatMapStringsSep "\n" (
                    name:
                    let
                      package = config.oci.internal.prefixedOCIs.${name};
                    in
                    ''
                      echo "Building container: ${name}"
                      cp ${package} $out/${name}
                    ''
                  ) (attrsets.attrNames config.oci.internal.prefixedOCIs)}
                '';
          };
          updatepulledOCIsManifestLocks = mkOption {
            type = types.package;
            internal = true;
            readOnly = true;
            default = localLib.mkOCIPulledManifestLockUpdateScript {
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
