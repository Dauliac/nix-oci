# Flake apps output - binds oci.flake.apps to flake outputs when enableFlakeOutputs is true
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
        apps = config.oci.flake.apps;
      };
  };
}
