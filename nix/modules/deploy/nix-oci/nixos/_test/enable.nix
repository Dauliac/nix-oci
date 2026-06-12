{ lib, ... }:
{
  options.testing.enable = lib.mkEnableOption "nix-oci test infrastructure";
}
