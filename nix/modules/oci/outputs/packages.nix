# OCI packages intermediate output.
#
# Uses pipeline-gated packages when available, falls back to raw images.
# Controlled by oci.flake.outputs.packages.
{
  config,
  lib,
  flake-parts-lib,
  ...
}:
let
  cfg = config;
  inherit (lib) mkOption types;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, ... }:
    {
      options.oci.flake.packages = mkOption {
        type = types.attrsOf types.package;
        description = "OCI container packages that can be exposed as flake outputs.";
        readOnly = true;
        default =
          if !(cfg.oci.flake.outputs.packages) then
            { }
          else
            let
              gated = config.oci.pipeline.prefixedGatedPackages;
            in
            if gated != { } then gated else config.oci.internal.prefixedOCIs;
      };
    }
  );
}
