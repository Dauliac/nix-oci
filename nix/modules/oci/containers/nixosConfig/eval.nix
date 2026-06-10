# Container nixosConfig.eval - unified NixOS evaluation
#
# Delegates to the shared evalContainerNixos function (nix/lib/eval-container.nix)
# so that flake-parts and deploy modules use the exact same eval pipeline.
{
  lib,
  import-tree,
  nixLibNixosModule,
  ...
}:
let
  inherit (lib) mkOption types;
  ociNixOSModules = import-tree ../../../_nixos-oci;
  evalContainerLib = import ../../../../lib/eval-container.nix { inherit lib; };
in
{
  config.perSystem =
    { pkgs, ... }:
    {
      oci.perContainer =
        {
          config,
          perSystemConfig,
          globalConfig,
          ...
        }:
        let
          nixosCfg = config.nixosConfig;
          homeCfg = config.homeConfig;
          hasFromImage = config.fromImage.enabled or false;

          # Paths to pre-extracted base image identity files.
          # These are committed alongside the manifest lock by
          # `nix run .#oci-updatePulledManifestsLocks`.
          flakeLib = globalConfig.lib.flake.oci or { };
          basePasswdPath =
            if hasFromImage then
              flakeLib.mkOCIPulledBasePasswdPath {
                inherit (globalConfig.oci) fromImageManifestRootPath;
                inherit (config) fromImage;
              }
            else
              null;
          baseGroupPath =
            if hasFromImage then
              flakeLib.mkOCIPulledBaseGroupPath {
                inherit (globalConfig.oci) fromImageManifestRootPath;
                inherit (config) fromImage;
              }
            else
              null;

          result = evalContainerLib.evalContainerNixos {
            inherit
              pkgs
              ociNixOSModules
              nixLibNixosModule
              basePasswdPath
              baseGroupPath
              ;
            containerName = config._containerName;
            containerConfig = config;
            nixosModules = nixosCfg.modules;
            mainService = nixosCfg.mainService or null;
            homeManagerFlake = homeCfg.homeManagerFlake or null;
            homeModules = homeCfg.modules or [ ];
            fromImageEnabled = hasFromImage;
          };
        in
        {
          options.nixosConfig.eval = mkOption {
            type = types.nullOr types.unspecified;
            internal = true;
            readOnly = true;
            description = "The fully evaluated NixOS configuration for this container.";
            default = result.evalResult;
          };

          # Write the smart containerUser back to the flake-parts user option.
          # This ensures all image builders (mkSimpleOCI, mkNixOCI)
          # read the same user that the NixOS eval used for /etc/passwd.
          # Priority 50 (mkDefault) so explicit user = "foo" still wins.
          config.user = lib.mkDefault result.containerUser;
        };
    };
}
