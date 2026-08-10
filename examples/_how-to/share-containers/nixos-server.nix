# NixOS side of the "share containers between flake-parts and NixOS" how-to.
# Kept in its own file so both the standalone flake and the repo's tests can
# reference the exact same NixOS module.
{ pkgs, ... }:
{
  boot.isContainer = true;
  system.stateVersion = "25.11";

  oci = {
    enable = true;
    backend = "podman";
    containers.my-app = (import ./container.nix { inherit pkgs; }) // {
      autoStart = true;
    };
  };
}
