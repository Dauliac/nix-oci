{
  config,
  lib,
  inputs,
  self,
  ...
}:
let
  inherit (lib)
    mkIf
    ;
in
{
  config = mkIf (config.oci != null && config.oci.enabled) {
    perSystem =
      {
        config,
        pkgs,
        inputs',
        system,
        ...
      }:
      {
        apps = lib.mkMerge [
          {
            # BUG: fix puller
            oci-updatePulledManifestsLocks = {
              type = "app";
              program = config.oci.internal.updatepulledOCIsManifestLocks;
            };
          }
          config.oci.internal.prefixedCVEGrypeApps
          config.oci.internal.prefixedCVETrivyApps
          config.oci.internal.prefixedContainerStructureTestApps
          config.oci.internal.prefixedCredentialsLeakTrivyApps
          config.oci.internal.prefixedDgossApps
          config.oci.internal.prefixedSBOMSyftApps
        ];
      };
  };
}
