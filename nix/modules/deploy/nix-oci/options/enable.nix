# services.nix-oci.enable — registered for both NixOS and home-manager.
{ ... }:
let
  mod =
    { lib, ... }:
    {
      options.services.nix-oci.enable = lib.mkEnableOption "nix-oci container loader";
    };
in
{
  flake.modules.nixos.nix-oci-enable = mod;
  flake.modules.homeManager.nix-oci-enable = mod;
}
