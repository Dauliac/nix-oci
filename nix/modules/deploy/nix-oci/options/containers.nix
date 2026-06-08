# oci.containers — registered for both NixOS and home-manager.
#
# Submodule options are auto-discovered from _containers/ via import-tree.
# nix2container is threaded into the submodule so _containers/image.nix can build.
{ import-tree, ... }:
let
  containerSubmodule = import-tree ./_containers;
  mod =
    {
      lib,
      pkgs,
      nix2container,
      ...
    }:
    {
      options.oci.containers = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submoduleWith {
            modules = [ containerSubmodule ];
            specialArgs = { inherit pkgs nix2container; };
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
}
