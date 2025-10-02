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
        packages = lib.mkMerge [
          {
            # BUG: fix puller
            # oci-updatePulledManifestsLocks = updatepulledOCIsManifestLocks;
            oci-all = config.oci.internal.allOCIs;
          }
          config.oci.internal.prefixedOCIs
        ];
      };
  };
}
