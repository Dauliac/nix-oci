# oci.containers -- registered for NixOS, home-manager, and system-manager.
#
# Submodule imports SHARED option definitions from oci/containers/_options/
# (same source of truth as flake-parts) + deploy-specific extensions from _containers/.
# nix2container, ociLib, and ociNixOSModules are threaded into the submodule via specialArgs.
{ import-tree, ... }:
let
  # Shared core options (package, dependencies, isRoot, entrypoint, user, name, tag, etc.)
  sharedOptions = import-tree ../../../oci/containers/_options;
  # Deploy-specific extensions (autoStart, volumes, image, image-ref, nixos-config, _defaults)
  deployExtensions = import-tree ./_containers;

  # The internal NixOS module tree evaluated per container (service adapters,
  # entrypoint derivation, healthcheck, hardening, performance, etc.).
  ociNixOSModules = import-tree ../../../_nixos-oci;

  # Shared pure OCI library -- single source of truth for both
  # flake-parts (nix-lib) and deploy (NixOS/HM) consumers.
  mkOciLib = lib: import ../../../../lib/oci.nix { inherit lib; };

  mod =
    {
      config,
      lib,
      pkgs,
      nix2container,
      nixLibNixosModule ? null,
      ...
    }:
    let
      ociLib = mkOciLib lib;

      baseModules = [
        sharedOptions
        deployExtensions
      ];
    in
    {
      options.oci = {
        perContainer = lib.mkOption {
          type = lib.types.listOf lib.types.deferredModule;
          default = [ ];
          description = ''
            Extra modules applied to every container submodule.
            Use this to set defaults across all containers:

            ```nix
            oci.perContainer = [
              ({ lib, ... }: {
                config.layerStrategy = lib.mkDefault "fine-grained";
                config.optimizeLayers = lib.mkDefault true;
              })
            ];
            ```
          '';
        };

        containers = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submoduleWith {
              modules = baseModules ++ config.oci.perContainer;
              specialArgs = {
                inherit
                  pkgs
                  nix2container
                  ociLib
                  ociNixOSModules
                  nixLibNixosModule
                  ;
                examplesDir = ../../../../../examples;
              };
            }
          );
          default = { };
          description = ''
            OCI containers to build, load, and optionally run.
            Each entry builds an image via nix2container and creates
            a systemd service to load it into the container runtime.
          '';
        };
      };
    };
in
{
  flake.modules.nixos.nix-oci-containers = mod;
  flake.modules.homeManager.nix-oci-containers = mod;
  flake.modules.systemManager.nix-oci-containers = mod;
}
