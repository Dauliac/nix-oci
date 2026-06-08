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
            layerStrategy = oci.layerStrategy or "fine-grained";

            # Auto-generated labels (OCI standard + build info + hardening + PSS).
            # Merge order: auto-labels < NixOS-eval hardening labels < user labels.
            generatedLabels = ociLib.mkAutoLabels {
              name = oci.name;
              tag = oci.tag;
              package = oci.package;
              isRoot = oci.isRoot or false;
              optimizeLayers = optimized;
              inherit layerStrategy;
              hardening = oci.hardening or { enable = false; };
              ports = oci.ports or [ ];
              dependencies = oci.dependencies or [ ];
              system = pkgs.stdenv.hostPlatform.system;
              autoLabels = oci.autoLabels or true;
            };

            appCopyToRoot = [ out.rootFilesystem ] ++ lib.optional (oci.package != null) oci.package;

            # hwcaps layers from the host arch's archConfigs entry
            hostArch = pkgs.stdenv.hostPlatform.system;
            archPerf =
              if oci.archConfigs ? ${hostArch} then oci.archConfigs.${hostArch}.performance or { } else { };
            hwcapsLayers = lib.optionals (archPerf.hwcaps.enable or false) (
              map (
                level:
                ociLib.mkHwcapsLayer {
                  nix2container = perSystemConfig.packages.nix2container;
                  inherit level;
                  libraries = archPerf.hwcaps.libraries or [ ];
                }
              ) (archPerf.hwcaps.levels or [ ])
            );

            layers =
              (
                if optimized then
                  ociLib.mkImageLayers {
                    nix2container = perSystemConfig.packages.nix2container;
                    inherit layerStrategy;
                    dependencies = oci.dependencies;
                    copyToRoot = appCopyToRoot;
                  }
                else
                  [ ]
              )
              ++ hwcapsLayers;
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
              // {
                Labels =
                  generatedLabels
                  // (out.hardening.labels or { })
                  // (out.performance.labels or { })
                  // (oci.labels or { });
              }
              // (
                let
                  hc = out.healthcheck or null;
                in
                lib.optionalAttrs (hc != null) {
                  Healthcheck = {
                    Test = [ "CMD" ] ++ hc.command;
                    Interval = hc.interval * 1000000000;
                    Timeout = hc.timeout * 1000000000;
                    StartPeriod = hc.startPeriod * 1000000000;
                    Retries = hc.retries;
                  };
                }
              )
              // lib.optionalAttrs ((out.stopSignal or null) != null) {
                StopSignal = out.stopSignal;
              }
              // lib.optionalAttrs ((out.workingDir or null) != null) {
                WorkingDir = out.workingDir;
              }
              // (
                let
                  vols = out.declaredVolumes or [ ];
                in
                lib.optionalAttrs (vols != [ ]) {
                  Volumes = builtins.listToAttrs (map (v: lib.nameValuePair v { }) vols);
                }
              );
            }
            // lib.optionalAttrs (fromImage != null) {
              inherit fromImage;
            }
            // (
              if optimized then
                {
                  inherit layers;
                }
                // lib.optionalAttrs (layerStrategy == "fine-grained") {
                  maxLayers = 40;
                }
              else
                {
                  copyToRoot = appCopyToRoot;
                }
                // lib.optionalAttrs (hwcapsLayers != [ ]) {
                  layers = hwcapsLayers;
                }
            )
          );
      };
    };
}
