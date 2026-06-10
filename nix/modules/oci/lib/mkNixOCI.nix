# OCI mkNixOCI - Build a container with Nix support and build users
#
# Uses NixOS eval outputs for all image content -- same normalized flow as
# mkSimpleOCI. Nix-specific additions (nixbld users, nix.conf, nix packages)
# are handled by _nixos/oci/nix-support.nix in the NixOS eval.
# The only builder-specific parts are /nix/var dirs and permissions.
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
      nix-lib.lib.oci.mkNixOCI = {
        type = lib.types.functionTo lib.types.package;
        description = "Build a container with Nix support and build users";
        file = "nix/modules/oci/lib/mkNixOCI.nix";
        fn =
          args@{
            perSystemConfig,
            containerId,
          }:
          let
            oci = perSystemConfig.containers.${containerId};
            # Force-evaluate nixosConfig assertions/warnings
            _nixosChecks = oci.nixosConfig._checks or "";
            nixosEval = oci.nixosConfig.eval;
            out = nixosEval.oci.container._output;
            fullName =
              if oci.registry != null && oci.registry != "" then "${oci.registry}/${oci.name}" else oci.name;
            optimized = oci.optimizeLayers or false;
            layerStrategy = oci.layerStrategy or "fine-grained";
            initNixDb = oci.initializeNixDatabase or false;

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

            # Nix-specific: /nix/var directories and permissions from NixOS eval
            nixVarDirs = out.nixVarDirs;
            nixPerms = out.nixPerms or [ ];

            # Root filesystem from NixOS eval -- includes shadow files (with nixbld
            # users), etc files (nix.conf, nsswitch, certs), packages (nix, bash,
            # coreutils), dependencies, home dir.
            # rootFilesystem (buildEnv) already includes oci.package -- adding it
            # again would cause nix2container collisions when the package uses
            # makeWrapper (symlink-vs-real-file conflict, e.g. PostgreSQL).
            appCopyToRoot = [
              out.rootFilesystem
            ]
            ++ lib.optional (nixVarDirs != null) nixVarDirs;

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
            // lib.optionalAttrs (optimized && layerStrategy == "fine-grained") {
              maxLayers = 40;
            }
          );
      };
    };
}
