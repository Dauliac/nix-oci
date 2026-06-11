{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  cfg = config;
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
          amicontainedOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "test.amicontained";
            };
          };
          amicontainedApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: oci:
              ociLib.mkAppAmicontained {
                perSystemConfig = config.oci;
                inherit containerId;
              }
            ) config.oci.internal.amicontainedOCIs;
          };
          prefixedAmicontainedApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.prefixOutputs {
              prefix = "oci-amicontained-";
              set = config.oci.internal.amicontainedApps;
            };
          };
        };
      }
    );
  };
}
