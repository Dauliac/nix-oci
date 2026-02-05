# OCI apps intermediate output
{
  lib,
  flake-parts-lib,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    any
    attrValues
    ;
in
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, ... }:
    {
      options.oci.flake.apps = mkOption {
        type = types.attrsOf types.attrs;
        description = "OCI-related apps that can be exposed as flake outputs.";
        readOnly = true;
        defaultText = lib.literalMD "Apps for security scanning, SBOM generation, validation, and multi-arch builds, derived from [`oci.containers`](#opt-perSystem.oci.containers).";
        default =
          let
            hasExternalDependencies = any (containerConfig: containerConfig.fromImage.enabled) (
              attrValues config.oci.containers
            );
            updateManifestApp =
              if hasExternalDependencies then
                {
                  oci-updatePulledManifestsLocks = {
                    type = "app";
                    program = config.oci.internal.updatepulledOCIsManifestLocks;
                  };
                }
              else
                { };
          in
          updateManifestApp
          // config.oci.internal.prefixedCVEGrypeApps
          // config.oci.internal.prefixedCVETrivyApps
          // config.oci.internal.prefixedContainerStructureTestApps
          // config.oci.internal.prefixedCredentialsLeakTrivyApps
          // config.oci.internal.prefixedDgossApps
          // config.oci.internal.prefixedSBOMSyftApps
          // config.oci.internal.prefixedPushTmpOCIApps
          // config.oci.internal.prefixedMergeMultiArchApps;
      };
    }
  );
}
