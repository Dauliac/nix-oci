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
          policyConftestChecks = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: _:
              ociLib.mkCheckPolicyConftest {
                perSystemConfig = config.oci;
                globalConfig = cfg.oci;
                inherit containerId;
              }
            ) config.oci.internal.policyConftestOCIs;
          };
          prefixedPolicyConftestChecks = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.prefixOutputs {
              prefix = "oci-policy-conftest-";
              set = config.oci.internal.policyConftestChecks;
            };
          };
        };
      }
    );
  };
}
