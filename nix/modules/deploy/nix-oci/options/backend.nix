# oci.backend — registered for both NixOS and home-manager.
{ ... }:
let
  mod = { lib, ... }: {
    options.oci.backend = lib.mkOption {
      type = lib.types.enum [ "docker" "podman" ];
      default = "podman";
      description = "Container runtime backend to load and run images.";
    };
  };
in
{
  flake.modules.nixos.nix-oci-backend = mod;
  flake.modules.homeManager.nix-oci-backend = mod;
  flake.modules.systemManager.nix-oci-backend = mod;
}
