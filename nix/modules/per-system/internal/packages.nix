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
          prefixedOCIs = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.prefixOutputs {
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
