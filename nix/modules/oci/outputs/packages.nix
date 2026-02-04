# OCI packages intermediate output
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
      options.oci.outputs.packages = mkOption {
        type = types.attrsOf types.package;
        description = "OCI container packages that can be exposed as flake outputs.";
        readOnly = true;
        default = config.oci.internal.prefixedOCIs;
      };
    }
  );
}
