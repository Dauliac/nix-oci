# oci.enable — registered for both NixOS and home-manager.
{ ... }:
let
  mod = { lib, ... }: {
    options.oci.enable = lib.mkEnableOption "nix-oci container deployment";
  };
in
{
  flake.modules.nixos.nix-oci-enable = mod;
  flake.modules.homeManager.nix-oci-enable = mod;
  flake.modules.systemManager.nix-oci-enable = mod;
}
