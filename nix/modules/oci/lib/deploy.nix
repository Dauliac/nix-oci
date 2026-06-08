# Register shared deploy lib functions in the flake-parts nix-lib system.
#
# This makes `skopeoDestPrefix`, `mkImageRef`, `mkLoadServiceName`, and
# `copyScript` available as typed, documented functions via
# `config.lib.oci.*` in perSystem — the same definitions used by the
# NixOS and home-manager deploy modules.
{ lib, ... }:
{
  config.perSystem =
    { lib, ... }:
    let
      deployDefs = import ../../_lib/oci.nix { inherit lib; };
    in
    {
      nix-lib.lib.oci = {
        inherit (deployDefs)
          skopeoDestPrefix
          mkImageRef
          mkLoadServiceName
          copyScript
          ;
      };
    };
}
