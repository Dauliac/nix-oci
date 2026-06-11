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
          credentialsLeakTrivyChecks = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = attrsets.mapAttrs (
              containerId: _:
              ociLib.mkCheckCredentialsLeakTrivy {
                perSystemConfig = config.oci;
                inherit containerId;
              }
            ) config.oci.internal.credentialsLeakTrivyOCIs;
          };
          prefixedCredentialsLeakTrivyChecks = mkOption {
            type = types.attrsOf types.package;
            internal = true;
            readOnly = true;
            default = cfg.lib.flake.oci.prefixOutputs {
              prefix = "oci-credentials-leak-";
              set = config.oci.internal.credentialsLeakTrivyChecks;
            };
          };
        };
      }
    );
  };
}
