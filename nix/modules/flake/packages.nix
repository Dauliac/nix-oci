# Flake packages output - binds oci.flake.packages to flake outputs when enableFlakeOutputs is true
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
        packages = config.oci.flake.packages;
      };
  };
}
