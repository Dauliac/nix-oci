localflake:
{
  config,
  lib,
  inputs,
  self,
  flake-parts-lib,
  ...
}:
let
  localLib = localflake.config.lib;
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
      {
        options.oci.internal = {
          diveOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = localLib.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "test.dive";
            };
          };
          diveChecks = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: oci:
              localLib.mkCheckDive {
                inherit pkgs;
                oci = config.oci.internal.OCIs.${containerId};
                perSystemConfig = config.oci;
              }
            ) config.oci.internal.diveOCIs;
          };
          prefixedDiveChecks = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = localLib.prefixOutputs {
              prefix = "oci-dive-";
              set = config.oci.internal.diveChecks;
            };
          };
        };
      }
    );
  };
}
