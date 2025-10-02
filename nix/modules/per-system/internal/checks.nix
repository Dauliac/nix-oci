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
        ...
      }:
      {
        options.oci.internal = {
          diveOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.oci.lib.filterEnabledOutputsSet {
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
              cfg.oci.lib.mkCheckDive {
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
            default = cfg.oci.lib.prefixOutputs {
              prefix = "oci-dive-";
              set = config.oci.internal.diveChecks;
            };
          };
        };
      }
    );
  };
}
