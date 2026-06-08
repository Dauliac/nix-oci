# services.nix-oci.backend — registered for both NixOS and home-manager.
{ ... }:
let
  mod =
    { lib, ... }:
    {
      options.services.nix-oci.backend = lib.mkOption {
        type = lib.types.enum [
          "docker"
          "podman"
        ];
        default = "podman";
        description = "Container runtime backend to load images into.";
      };
    };
in
{
  flake.modules.nixos.nix-oci-backend = mod;
  flake.modules.homeManager.nix-oci-backend = mod;
}
