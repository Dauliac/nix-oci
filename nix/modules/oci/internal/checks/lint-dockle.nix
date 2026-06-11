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
          lintDockleChecks = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: _:
              ociLib.mkCheckLintDockle {
                perSystemConfig = config.oci;
                globalConfig = cfg.oci;
                inherit containerId;
              }
            ) config.oci.internal.lintDockleOCIs;
          };
          prefixedLintDockleChecks = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.prefixOutputs {
              prefix = "oci-lint-dockle-";
              set = config.oci.internal.lintDockleChecks;
            };
          };
        };
      }
    );
  };
}
