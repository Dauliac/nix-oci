# Flake checks output - extracts oci.outputs.checks when enableFlakeOutputs is true
{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;
in
{
  config = mkIf (config.oci.enabled && config.oci.enableFlakeOutputs) {
    perSystem =
      { config, ... }:
      {
        checks = config.oci.outputs.checks;
      };
  };
}
