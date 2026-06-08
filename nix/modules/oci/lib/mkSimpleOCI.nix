# OCI mkSimpleOCI - Build a simple container without Nix support
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
      nix-lib.lib.oci.mkSimpleOCI = {
        type = lib.types.functionTo lib.types.package;
        description = "Build a simple container without Nix support";
        fn =
          args@{
            perSystemConfig,
            containerId,
            globalConfig,
          }:
          let
            oci = perSystemConfig.containers.${containerId};
            # Force-evaluate nixosConfig assertions/warnings
            _nixosChecks = oci.nixosConfig._checks or "";
            nixosEval = oci.nixosConfig.eval;
            out = nixosEval.oci.container._output;
            fullName =
              if oci.registry != null && oci.registry != "" then "${oci.registry}/${oci.name}" else oci.name;
            fromImage =
              if !oci.fromImage.enabled then
                null
              else
                ociLib.mkOCIPulledManifestLock {
                  inherit perSystemConfig containerId globalConfig;
                };
            optimized = oci.optimizeLayers or false;

            appCopyToRoot = [ out.rootFilesystem ] ++ lib.optional (oci.package != null) oci.package;

            layers =
              if optimized then
                ociLib.mkImageLayers {
                  nix2container = perSystemConfig.packages.nix2container;
                  dependencies = oci.dependencies;
                  copyToRoot = appCopyToRoot;
                }
              else
                [ ];
          in
          assert _nixosChecks == "" || _nixosChecks != "";
          perSystemConfig.packages.nix2container.buildImage (
            {
              inherit (oci) tag;
              name = fullName;
              config = {
                entrypoint = if out.entrypoint != [ ] then out.entrypoint else oci.entrypoint;
                User = oci.user;
                Env = out.envVars;
              }
              // lib.optionalAttrs (oci.labels != { }) {
                Labels = oci.labels;
              };
            }
            // lib.optionalAttrs (fromImage != null) {
              inherit fromImage;
            }
            // (
              if optimized then
                {
                  inherit layers;
                  maxLayers = 40;
                }
              else
                {
                  copyToRoot = appCopyToRoot;
                }
            )
          );
      };
    };
}
