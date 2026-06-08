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
            depsLayers =
              if optimized && oci.dependencies != [ ] then
                [
                  (ociLib.mkDepsLayer {
                    inherit perSystemConfig;
                    dependencies = oci.dependencies;
                  })
                ]
              else
                [ ];
          in
          assert _nixosChecks == "" || _nixosChecks != "";
          perSystemConfig.packages.nix2container.buildImage (
            {
              inherit (oci) tag;
              name = fullName;
              # rootFilesystem has shadow, etc, home, deps, configFiles from NixOS eval.
              # Package is added separately (can't pass to NixOS eval without cycle).
              copyToRoot = [ out.rootFilesystem ] ++ lib.optional (oci.package != null) oci.package;
              config = {
                # Use NixOS-generated entrypoint for service containers,
                # fall back to flake-parts entrypoint for simple containers
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
            // lib.optionalAttrs optimized {
              layers = depsLayers;
              maxLayers = 40;
            }
          );
      };
    };
}
