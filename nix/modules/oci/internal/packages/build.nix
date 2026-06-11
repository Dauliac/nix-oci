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
          OCIs = mkOption {
            description = "Built OCI container images.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: containerConfig:
              ociLib.mkOCI {
                perSystemConfig = config.oci;
                globalConfig = cfg.oci;
                inherit containerId;
              }
            ) config.oci.containers;
          };
          flavourOCIs = mkOption {
            description = "Built OCI images from flavour expansion.";
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default =
              let
                flavourContainers = config.oci.internal._flavourContainers;
                allPerSystem = config.oci // {
                  containers = config.oci.containers // flavourContainers;
                };
              in
              attrsets.mapAttrs (
                syntheticId: _:
                ociLib.mkOCI {
                  perSystemConfig = allPerSystem;
                  globalConfig = cfg.oci;
                  containerId = syntheticId;
                }
              ) flavourContainers;
          };
          _flavourPerSystem = mkOption {
            type = types.unspecified;
            internal = true;
            readOnly = true;
            description = "Merged perSystemConfig for flavour-aware lookups (containers + OCIs).";
            default =
              let
                flavourContainers = config.oci.internal._flavourContainers;
              in
              config.oci
              // {
                containers = config.oci.containers // flavourContainers;
                internal = config.oci.internal // {
                  OCIs = config.oci.internal.OCIs // config.oci.internal.flavourOCIs;
                };
              };
          };
          prefixedOCIs = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.prefixOutputs {
              prefix = "oci-";
              set = config.oci.internal.OCIs // config.oci.internal.flavourOCIs;
            };
          };
        };
      }
    );
  };
}
