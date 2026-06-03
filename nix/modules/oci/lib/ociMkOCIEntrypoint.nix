# Derive container entrypoint from package
{ lib, ... }:
let
  # Resolve the program name from a package, with fallback chain:
  # meta.mainProgram -> pname -> parsed derivation name
  resolveMainProgram =
    package:
    if package.meta.mainProgram or null != null then
      package.meta.mainProgram
    else if package.pname or null != null then
      package.pname
    else
      (builtins.parseDrvName (package.name or "unknown")).name;
in
{
  nix-lib.lib.oci.mkOCIEntrypoint = {
    type = lib.types.functionTo (lib.types.listOf lib.types.str);
    description = "Derive container entrypoint from package mainProgram, pname, or derivation name";
    fn = { package }: if package != null then [ "/bin/${resolveMainProgram package}" ] else [ ];
    tests = {
      "derives entrypoint from package mainProgram" = {
        args = {
          package = {
            meta.mainProgram = "myapp";
          };
        };
        expected = [ "/bin/myapp" ];
      };
      "derives entrypoint from pname when mainProgram is missing" = {
        args = {
          package = {
            pname = "my-script";
            name = "my-script";
            meta = { };
          };
        };
        expected = [ "/bin/my-script" ];
      };
      "derives entrypoint from derivation name as last resort" = {
        args = {
          package = {
            name = "my-script";
            meta = { };
          };
        };
        expected = [ "/bin/my-script" ];
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
