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
          SBOMSyftOCIs = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.filterEnabledOutputsSet {
              config = config.oci.containers;
              subConfig = "sbom.syft";
            };
          };
          SBOMSyftOCIsApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: oci:
              ociLib.mkAppSBOMSyft {
                perSystemConfig = config.oci;
                inherit containerId;
              }
            ) config.oci.internal.SBOMSyftOCIs;
          };
          prefixedSBOMSyftApps = mkOption {
            type = types.attrs;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.prefixOutputs {
              prefix = "oci-sbom-syft-";
              set = config.oci.internal.SBOMSyftOCIsApps;
            };
          };
        };
      }
    );
  };
}
