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
      let
        ociLib = config.lib.oci or { };
      in
      {
        options.oci.internal = {
          diveOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.filterEnabledOutputsSet {
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
              ociLib.mkCheckDive {
                perSystemConfig = config.oci;
                inherit containerId;
              }
            ) config.oci.internal.diveOCIs;
          };
          prefixedDiveChecks = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.prefixOutputs {
              prefix = "oci-dive-";
              set = config.oci.internal.diveChecks;
            };
          };
        };
      }
    );
  };
}
