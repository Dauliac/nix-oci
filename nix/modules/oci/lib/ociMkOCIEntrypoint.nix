# Derive container entrypoint from package
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  nix-lib.lib.oci.mkOCIEntrypoint = {
    type = lib.types.functionTo (lib.types.listOf lib.types.str);
    description = "Derive container entrypoint from package mainProgram, pname, or derivation name";
        file = "nix/modules/oci/lib/ociMkOCIEntrypoint.nix";
    fn = { package }: if package != null then [ "/bin/${pure.resolveMainProgram package}" ] else [ ];
    tests = {
      "derives entrypoint from mainProgram" = {
        args = {
          package = {
            meta.mainProgram = "nginx";
            pname = "nginx";
            name = "nginx-1.25";
          };
        };
        expected = [ "/bin/nginx" ];
      };
      "returns empty list when package is null" = {
        args = {
          package = null;
        };
        expected = [ ];
      };
    };
  };
}
