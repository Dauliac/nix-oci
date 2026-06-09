# oci.containers -- registered for NixOS, home-manager, and system-manager.
#
# Submodule imports SHARED option definitions from oci/containers/_options/
# (same source of truth as flake-parts) + deploy-specific extensions from _containers/.
# nix2container and ociLib are threaded into the submodule via specialArgs.
{ import-tree, ... }:
let
  # Shared core options (package, dependencies, isRoot, entrypoint, user, name, tag, etc.)
  sharedOptions = import-tree ../../../oci/containers/_options;
  # Deploy-specific extensions (autoStart, volumes, image, image-ref, _defaults)
  deployExtensions = import-tree ./_containers;

  # Shared pure OCI library -- single source of truth for both
  # flake-parts (nix-lib) and deploy (NixOS/HM) consumers.
  mkOciLib = lib: import ../../../../lib/oci.nix { inherit lib; };

  mod =
    {
      lib,
      pkgs,
      nix2container,
      ...
    }:
    let
      ociLib = mkOciLib lib;
    in
    {
      options.oci.containers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submoduleWith {
            modules = [
              sharedOptions
              deployExtensions
            ];
            specialArgs = {
              inherit pkgs nix2container ociLib;
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
in
{
  flake.modules.nixos.nix-oci-containers = mod;
  flake.modules.homeManager.nix-oci-containers = mod;
  flake.modules.systemManager.nix-oci-containers = mod;
}
