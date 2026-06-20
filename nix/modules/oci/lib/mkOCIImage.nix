# OCI mkOCIImage - Single unified build function for all container types.
#
# Replaces mkSimpleOCI + mkNixOCI + mkNixOrSimpleOCI with ONE function.
# No branching on installNix or isRoot -- the NixOS eval produces the
# correct _output.* for every container type via central routing:
#   - environment.variables → _output.envVars
#   - oci.container.extraPackages → _output.rootFilesystem
#   - oci.container.generatedLabels → Labels
#   - oci.container.includedEtcFiles → _output.etcFiles
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
      nix-lib.lib.oci.mkOCIImage = {
        type = lib.types.functionTo lib.types.package;
        description = "Build an OCI container image from NixOS eval outputs (unified, no branching).";
        file = "nix/modules/oci/lib/mkOCIImage.nix";
        fn =
          {
            perSystemConfig,
            containerId,
            ...
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
              if !(oci.fromImage.enabled or false) then
                null
              else
                ociLib.mkOCIPulledManifestLock {
                  inherit perSystemConfig containerId;
                };

            optimized = oci.optimizeLayers or false;
            layerStrategy = oci.layerStrategy or "fine-grained";

            # Auto-generated labels (OCI standard + build info).
            autoLabels = ociLib.mkAutoLabels {
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

            # rootFilesystem from NixOS eval -- includes ALL packages (main, adapters,
            # perf allocator, GPU libs, nix tooling, shadow files, etc files, home dir).
            # The NixOS eval handles all variations via central routing.
            appCopyToRoot = [
              out.rootFilesystem
            ]
            ++ lib.optional ((out.nixVarDirs or null) != null) out.nixVarDirs;

            # hwcaps layers from the host arch's archConfigs entry
            hostArch = pkgs.stdenv.hostPlatform.system;
            archPerf =
              if oci.archConfigs or { } ? ${hostArch} then
                (oci.archConfigs.${hostArch}).performance or { }
              else
                { };
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

            # Nix-in-container support: permissions and DB init (nullable, from NixOS eval)
            nixPerms = out.nixPerms or [ ];
            initNixDb = oci.initializeNixDatabase or false;

            # OCI image config -- uniform for all container types
            ociConfig = {
              entrypoint = if out.entrypoint != [ ] then out.entrypoint else oci.entrypoint;
              User = oci.user;
              Env = out.envVars;
            }
            // {
              # Labels: auto-generated + unified generatedLabels + user overrides
              Labels = autoLabels // (nixosEval.oci.container.generatedLabels or { }) // (oci.labels or { });
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
          in
          assert _nixosChecks == "" || _nixosChecks != "";
          perSystemConfig.packages.nix2container.buildImage (
            {
              inherit (oci) tag;
              name = fullName;
              config = ociConfig;
              copyToRoot = appCopyToRoot;
            }
            // lib.optionalAttrs (fromImage != null) {
              inherit fromImage;
            }
            // lib.optionalAttrs (nixPerms != [ ]) {
              perms = nixPerms;
            }
            // lib.optionalAttrs initNixDb {
              initializeNixDatabase = true;
              nixUid = if oci.isRoot or false then 0 else oci.uid or 4000;
              nixGid = if oci.isRoot or false then 0 else oci.gid or 4000;
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
                { }
                // lib.optionalAttrs (hwcapsLayers != [ ]) {
                  layers = hwcapsLayers;
                }
            )
          );
      };
    };
}
