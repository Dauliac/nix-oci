# oci.containers -- registered for NixOS, home-manager, and system-manager.
#
# Submodule imports SHARED option definitions from oci/containers/_options/
# (same source of truth as flake-parts) + deploy-specific extensions from _containers/.
# nix2container, ociLib, and ociNixOSModules are threaded into the submodule via specialArgs.
{ lib, ... }:
let
  discoverModules = import ../../../../lib/discoverModules.nix { inherit lib; };
  # Shared core options (package, dependencies, isRoot, entrypoint, user, name, tag, etc.)
  sharedOptions = {
    imports = discoverModules ../../../oci/containers/_options;
  };
  # Deploy-specific extensions (autoStart, volumes, image, image-ref, nixos-config, _defaults)
  deployExtensions = {
    imports = discoverModules ./_containers;
  };

  # The internal NixOS module tree evaluated per container (service adapters,
  # entrypoint derivation, healthcheck, hardening, performance, etc.).
  ociNixOSModules = {
    imports = discoverModules ../../../_nixos-oci;
  };

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
      # Reads config._module.args.ociLib if some other module in this eval
      # set it (docs generation injects a stub there that no-ops
      # derivation-producing functions which can't evaluate during docs
      # builds); otherwise computes the real one. NOT a function argument:
      # nixpkgs resolves missing module-function arguments by querying
      # config._module.args unconditionally, which would shadow a `?`
      # default and throw for every real deployment (mod is imported
      # directly into NixOS/HM/system-manager configs, which never set
      # _module.args.ociLib).
      ociLib = config._module.args.ociLib or (mkOciLib lib);

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
                # Deploy-time container runtime selection, threaded through
                # to the nested per-container NixOS eval so hardening
                # coherence checks can detect backend-specific limitations
                # (e.g. nixpkgs' podman lacks AppArmor support). Not
                # meaningful for flake-side (build-only) containers, which
                # have no backend selection; evalContainerNixos defaults it
                # to null there.
                backend = config.oci.backend;
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
