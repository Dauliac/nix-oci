{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkIf
    ;
in
{
  config = mkIf config.oci.enabled {
    perSystem =
      { config, ... }:
      {
        packages = config.oci.internal.prefixedOCIs;
      };
  };
}
