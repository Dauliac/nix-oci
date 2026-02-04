# OCI checks intermediate output
{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, ... }:
    {
      options.oci.outputs.checks = mkOption {
        type = types.attrsOf types.package;
        description = "OCI-related checks that can be exposed as flake outputs.";
        readOnly = true;
        default = config.oci.internal.prefixedDiveChecks;
      };
    }
  );
}
