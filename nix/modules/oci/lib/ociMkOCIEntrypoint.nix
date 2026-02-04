# Derive container entrypoint from package mainProgram
{ lib, ... }:
{
  nix-lib.lib.oci.mkOCIEntrypoint = {
    type = lib.types.functionTo (lib.types.listOf lib.types.str);
    description = "Derive container entrypoint from package mainProgram";
    fn = { package }: if package != null then [ "/bin/${package.meta.mainProgram}" ] else [ ];
    tests = {
      "derives entrypoint from package mainProgram" = {
        args = {
          package = {
            meta.mainProgram = "myapp";
          };
        };
        expected = [ "/bin/myapp" ];
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
