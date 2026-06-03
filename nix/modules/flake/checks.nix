# Flake checks output - binds oci.flake.checks to flake outputs when enableFlakeOutputs is true
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
        checks = config.oci.flake.checks;
      };
  };
}
