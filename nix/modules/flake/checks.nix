{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    ;
in
{
  config = mkIf config.oci.enabled {
    perSystem =
      { config, ... }:
      {
        checks = mkMerge [
          config.oci.internal.prefixedDiveChecks
        ];
      };
  };
}
