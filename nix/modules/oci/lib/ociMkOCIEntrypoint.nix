# Derive container entrypoint from package
{ lib, ... }:
let
  pure = import ../../../../lib/oci.nix { inherit lib; };
in
{
  nix-lib.lib.oci.mkOCIEntrypoint = {
    type = lib.types.functionTo (lib.types.listOf lib.types.str);
    description = "Derive container entrypoint from package mainProgram, pname, or derivation name";
    fn = { package }: if package != null then [ "/bin/${pure.resolveMainProgram package}" ] else [ ];
  };
}
