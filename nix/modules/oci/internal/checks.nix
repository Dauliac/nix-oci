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

        # Helper: filter containers where both `enabled` and `hermetic` are true
        filterHermeticContainers =
          subConfig:
          attrsets.filterAttrs (
            _: containerConfig:
            let
              sub = lib.attrByPath (lib.splitString "." subConfig) { } containerConfig;
            in
            (sub.enabled or false) && (sub.hermetic or false)
          ) config.oci.containers;
      in
      {
        options.oci.internal = {
          # ── Dive (unchanged) ──
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

          # ── Dgoss hermetic checks ──
          dgossHermeticOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = filterHermeticContainers "test.dgoss";
          };
          dgossChecks = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: _:
              ociLib.mkCheckDgoss {
                perSystemConfig = config.oci;
                inherit containerId;
              }
            ) config.oci.internal.dgossHermeticOCIs;
          };
          prefixedDgossChecks = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.prefixOutputs {
              prefix = "oci-dgoss-";
              set = config.oci.internal.dgossChecks;
            };
          };
        };
      }
    );
  };
}
