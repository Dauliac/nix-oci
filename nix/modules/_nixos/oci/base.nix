# Container baseline: boot.isContainer, disable docs, stateVersion
{ lib, ... }:
{
  config = {
    boot.isContainer = true;
    documentation.enable = lib.mkDefault false;
    documentation.man.enable = lib.mkDefault false;
    documentation.nixos.enable = lib.mkDefault false;
    system.stateVersion = lib.mkDefault "25.05";
  };
}
