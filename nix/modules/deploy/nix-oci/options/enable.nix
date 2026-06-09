# oci.enable -- registered for NixOS, home-manager, and system-manager.
{ ... }:
let
  mod =
    { lib, ... }:
    {
      options.oci.enable = lib.mkEnableOption "nix-oci container deployment";
    };
in
{
  flake.modules.nixos.nix-oci-enable = mod;
  flake.modules.homeManager.nix-oci-enable = mod;
  flake.modules.systemManager.nix-oci-enable = mod;
}
