# OCI mkDebugOCI - Build a debug variant that shares layers with production
#
# Instead of rebuilding the entire image from scratch, the debug image is
# assembled by taking the production image's layer stack and appending a
# thin debug layer on top. Because the debug layer is folded after the
# production layers, nix2container deduplicates all shared store paths.
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

            entrypointWrapper = if oci.debug.entrypoint.enabled then oci.debug.entrypoint.wrapper else null;

            debugEntrypoint =
              if oci.debug.entrypoint.enabled then
                [ "${oci.debug.entrypoint.wrapper}/bin/entrypoint" ] ++ oci.entrypoint
              else
                oci.entrypoint;

            debugLabels = oci.debug.labels or oci.labels;

            # --- Optimized path: layer the debug on top of production layers ---
            #
            # For mkSimpleOCI-based images:
            nixosEval = oci.nixosConfig.eval;
            out = nixosEval.oci.container._output;
            simpleAppCopyToRoot = [ out.rootFilesystem ] ++ lib.optional (oci.package != null) oci.package;

            # For mkNixOCI-based images:
            installNix = oci.installNix or false;
            pkg = if oci.package != null then [ oci.package ] else [ ];
            deps = oci.dependencies or [ ];
            nixAppPaths = if optimized then pkg ++ [ pkgs.cacert ] else pkg ++ deps ++ [ pkgs.cacert ];
            nixAppPackages = pkgs.buildEnv {
              name = "app-root";
              paths = nixAppPaths;
              pathsToLink = [
                "/bin"
                "/lib"
                "/etc"
              ];
              ignoreCollisions = true;
            };
            home = if oci.user == "root" then "/root" else "/home/${oci.user}";
            homeDir = pkgs.runCommand "home-dir" { } ''
              mkdir -p $out${home}
            '';
            nixVarDirs = pkgs.runCommand "nix-var-dirs" { } ''
              mkdir -p $out/nix/var/nix/profiles/per-user/${oci.user}
              mkdir -p $out/nix/var/nix/gcroots/per-user/${oci.user}
              mkdir -p $out/nix/var/nix/temproots
            '';
            configFiles = oci.configFiles or [ ];
            configFilesLayerDefs = if configFiles != [ ] then [ { copyToRoot = configFiles; } ] else [ ];

            fullName =
              if oci.registry != null && oci.registry != "" then "${oci.registry}/${oci.name}" else oci.name;

            fromImage =
              if !(oci.fromImage.enabled or false) then
                null
              else
                ociLib.mkOCIPulledManifestLock {
                  inherit perSystemConfig containerId globalConfig;
                };

            # Build all layers including debug, with full deduplication
            debugDef = {
              packages = oci.debug.packages;
              inherit entrypointWrapper;
            };

            # Simple (non-Nix) path
            simpleLayers = ociLib.mkImageLayers {
              nix2container = perSystemConfig.packages.nix2container;
              inherit layerStrategy;
              dependencies = deps;
              copyToRoot = simpleAppCopyToRoot;
              debug = debugDef;
            };

            # Nix path
            nixLayer = ociLib.mkNixOCILayer {
              inherit perSystemConfig;
              user = oci.user;
              inherit home;
            };
            nixLayers = ociLib.mkImageLayers {
              nix2container = perSystemConfig.packages.nix2container;
              inherit layerStrategy;
              prependBuiltLayers = [ nixLayer ];
              prependLayerDefs = configFilesLayerDefs;
              dependencies = deps;
              copyToRoot = [
                nixAppPackages
                homeDir
                nixVarDirs
              ];
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
            # Optimized: share layers with production, append debug layer
            if installNix then
              perSystemConfig.packages.nix2container.buildImage (
                {
                  tag = oci.tag + "-debug";
                  name = fullName;
                  copyToRoot = [
                    nixAppPackages
                    homeDir
                    nixVarDirs
                  ];
                  perms = lib.optionals (oci.user != "root") [
                    {
                      path = nixVarDirs;
                      regex = "/nix/var/nix/.*";
                      mode = "0755";
                      uid = 4000;
                      gid = 4000;
                    }
                  ];
                  layers = nixLayers;
                  config = {
                    entrypoint = debugEntrypoint;
                    User = oci.user;
                    Env = [
                      "PATH=/bin:${home}/.nix-profile/bin:/nix/var/nix/profiles/default/bin"
                      "LANG=C.UTF-8"
                      "LC_ALL=C.UTF-8"
                      "NIX_PAGER=cat"
                      "SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt"
                      "USER=${oci.user}"
                      "HOME=${home}"
                    ];
                  }
                  // lib.optionalAttrs (debugLabels != { }) {
                    Labels = debugLabels;
                  };
                }
                // lib.optionalAttrs (layerStrategy == "fine-grained") {
                  maxLayers = 40;
                }
              )
            else
              perSystemConfig.packages.nix2container.buildImage (
                {
                  tag = oci.tag + "-debug";
                  name = fullName;
                  layers = simpleLayers;
                  config = {
                    entrypoint =
                      if out.entrypoint != [ ] then
                        (
                          if oci.debug.entrypoint.enabled then
                            [ "${oci.debug.entrypoint.wrapper}/bin/entrypoint" ] ++ out.entrypoint
                          else
                            out.entrypoint
                        )
                      else
                        debugEntrypoint;
                    User = oci.user;
                    Env = out.envVars;
                  }
                  // lib.optionalAttrs (debugLabels != { }) {
                    Labels = debugLabels;
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
            # Non-optimized fallback: rebuild entire image with merged deps
            ociLib.mkNixOrSimpleOCI {
              perSystemConfig = fallbackPerSystemConfig;
              inherit containerId globalConfig;
            };
      };
    };
}
