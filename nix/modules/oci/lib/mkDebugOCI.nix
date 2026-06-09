# OCI mkDebugOCI - Build a debug variant that shares layers with production
#
# Uses NixOS eval outputs for all image content — same normalized flow as
# mkSimpleOCI and mkNixOCI. No separate installNix/simple paths needed;
# the NixOS eval already includes Nix packages when installNix=true.
#
# Result in the registry:
#   Prod:  [deps] [app]
#   Debug: [deps] [app] [debug]  ← first two layers are byte-identical
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
      nix-lib.lib.oci.mkDebugOCI = {
        type = lib.types.functionTo lib.types.package;
        description = "Build a debug variant that shares layers with the production image";
        fn =
          args@{
            perSystemConfig,
            containerId,
            globalConfig,
          }:
          let
            oci = perSystemConfig.containers.${containerId};
            optimized = oci.optimizeLayers or false;
            layerStrategy = oci.layerStrategy or "fine-grained";
            initNixDb = oci.initializeNixDatabase or false;

            # NixOS eval outputs — single source of truth
            nixosEval = oci.nixosConfig.eval;
            out = nixosEval.oci.container._output;

            entrypointWrapper = if oci.debug.entrypoint.enabled then oci.debug.entrypoint.wrapper else null;

            # Wrap the NixOS eval entrypoint (service-derived) with debug wrapper
            prodEntrypoint = if out.entrypoint != [ ] then out.entrypoint else oci.entrypoint;
            debugEntrypoint =
              if oci.debug.entrypoint.enabled then
                [ "${oci.debug.entrypoint.wrapper}/bin/entrypoint" ] ++ prodEntrypoint
              else
                prodEntrypoint;

            debugLabels = oci.debug.labels or oci.labels;

            generatedLabels = ociLib.mkAutoLabels {
              name = oci.name;
              tag = oci.tag + "-debug";
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

            fullName =
              if oci.registry != null && oci.registry != "" then "${oci.registry}/${oci.name}" else oci.name;

            fromImage =
              if !(oci.fromImage.enabled or false) then
                null
              else
                ociLib.mkOCIPulledManifestLock {
                  inherit perSystemConfig containerId globalConfig;
                };

            deps = oci.dependencies or [ ];

            # Nix-specific dirs from eval (null when installNix=false)
            nixVarDirs = out.nixVarDirs or null;
            nixPerms = out.nixPerms or [ ];

            # Root filesystem from NixOS eval — same for all builder types.
            # rootFilesystem (buildEnv) already includes oci.package — adding it
            # again would cause nix2container collisions when the package uses
            # makeWrapper (symlink-vs-real-file conflict, e.g. PostgreSQL).
            appCopyToRoot = [
              out.rootFilesystem
            ]
            ++ lib.optional (nixVarDirs != null) nixVarDirs;

            debugDef = {
              packages = oci.debug.packages;
              inherit entrypointWrapper;
            };

            layers = ociLib.mkImageLayers {
              nix2container = perSystemConfig.packages.nix2container;
              inherit layerStrategy;
              dependencies = deps;
              copyToRoot = appCopyToRoot;
              debug = debugDef;
            };

            # --- Fallback path: non-optimized, rebuild with merged deps ---
            fallbackConfig = {
              tag = oci.tag + "-debug";
              dependencies =
                oci.dependencies
                ++ oci.debug.packages
                ++ lib.optional (entrypointWrapper != null) entrypointWrapper;
              entrypoint = debugEntrypoint;
              labels = debugLabels;
            };
            fallbackPerSystemConfig = perSystemConfig // {
              containers = perSystemConfig.containers // {
                ${containerId} = oci // fallbackConfig;
              };
            };
          in
          if optimized then
            perSystemConfig.packages.nix2container.buildImage (
              {
                tag = oci.tag + "-debug";
                name = fullName;
                copyToRoot = appCopyToRoot;
                perms = nixPerms;
                inherit layers;
              }
              // lib.optionalAttrs initNixDb {
                initializeNixDatabase = true;
                nixUid = if oci.user == "root" then 0 else 4000;
                nixGid = if oci.user == "root" then 0 else 4000;
              }
              // {
                config = {
                  entrypoint = debugEntrypoint;
                  User = oci.user;
                  Env = out.envVars;
                }
                // {
                  Labels = generatedLabels // (out.hardening.labels or { }) // debugLabels;
                };
              }
              // lib.optionalAttrs (fromImage != null) {
                inherit fromImage;
              }
              // lib.optionalAttrs (layerStrategy == "fine-grained") {
                maxLayers = 40;
              }
            )
          else
            ociLib.mkNixOrSimpleOCI {
              perSystemConfig = fallbackPerSystemConfig;
              inherit containerId globalConfig;
            };
      };
    };
}
