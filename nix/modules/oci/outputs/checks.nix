# OCI checks intermediate output.
#
# Pipeline-generated gate checks come from oci.pipeline.checks.
# Each container gets one gate check that forces all pure+vm stamps.
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
      options.oci.flake.checks = mkOption {
        type = types.attrsOf types.package;
        description = "OCI-related checks that can be exposed as flake outputs.";
        readOnly = true;
        default = config.oci.pipeline.checks;
      };
    }
  );
}
