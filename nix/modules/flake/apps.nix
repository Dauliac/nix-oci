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
    any
    attrValues
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
      let
        # Check if any container has external dependencies (fromImage)
        hasExternalDependencies = any (containerConfig: containerConfig.fromImage != null) (
          attrValues config.oci.containers
        );
      in
      {
        apps = lib.mkMerge [
          # Only create updatePulledManifestsLocks if containers have external dependencies
          (mkIf hasExternalDependencies {
            oci-updatePulledManifestsLocks = {
              type = "app";
              program = config.oci.internal.updatepulledOCIsManifestLocks;
            };
          })
          config.oci.internal.prefixedCVEGrypeApps
          config.oci.internal.prefixedCVETrivyApps
          config.oci.internal.prefixedContainerStructureTestApps
          config.oci.internal.prefixedCredentialsLeakTrivyApps
          config.oci.internal.prefixedDgossApps
          config.oci.internal.prefixedSBOMSyftApps
          config.oci.internal.prefixedPushTmpOCIApps
          config.oci.internal.prefixedMergeMultiArchApps
        ];
      };
  };
}
