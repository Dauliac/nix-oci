# Flake packages output - extracts oci.outputs.packages when enableFlakeOutputs is true
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
        packages = config.oci.outputs.packages;
      };
  };
}
