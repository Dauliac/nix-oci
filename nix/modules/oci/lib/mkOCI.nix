# OCI mkOCI - Main function to build container with all conditional features
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
    in
    {
      nix-lib.lib.oci.mkOCI = {
        type = lib.types.functionTo lib.types.package;
        description = "Main function to build container with all conditional features";
        fn =
          args@{
            perSystemConfig,
            containerId,
            globalConfig,
          }:
          let
            oci = perSystemConfig.containers.${containerId};
            package = ociLib.mkNixOrSimpleOCI { inherit perSystemConfig containerId globalConfig; };
          in
          package
          // (
            if oci.cve.trivy.enabled then
              {
                cve.trivy = ociLib.mkScriptCVETrivy {
                  inherit containerId perSystemConfig globalConfig;
                };
              }
            else
              { }
          )
          // (
            if oci.cve.grype.enabled then
              {
                cve.grype = ociLib.mkScriptCVEGrype {
                  inherit containerId perSystemConfig;
                };
              }
            else
              { }
          )
          // (
            if oci.sbom.syft.enabled then
              {
                sbom.syft = ociLib.mkScriptSBOMSyft {
                  inherit containerId perSystemConfig;
                };
              }
            else
              { }
          )
          // (
            if oci.credentialsLeak.trivy.enabled then
              {
                credentialsLeak.trivy = ociLib.mkScriptCredentialsLeakTrivy {
                  inherit containerId perSystemConfig;
                };
              }
            else
              { }
          )
          // (
            if oci.test.containerStructureTest.enabled then
              {
                containerStructureTest = ociLib.mkScriptContainerStructureTest {
                  inherit containerId perSystemConfig;
                };
              }
            else
              { }
          )
          // (
            if oci.debug.enabled then
              {
                debug = ociLib.mkDebugOCI { inherit perSystemConfig containerId globalConfig; };
              }
            else
              { }
          );
      };
    };
}
