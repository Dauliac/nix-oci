# Resolve the main program name from a package
#
# Fallback chain: meta.mainProgram → pname → parsed derivation name.
# Shared by mkOCIName and mkOCIEntrypoint.
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  nix-lib.lib.oci.resolveMainProgram = {
    type = lib.types.functionTo lib.types.str;
    description = ''
      Resolve the main program name from a package.

      Fallback chain:
      1. `meta.mainProgram` (preferred)
      2. `pname`
      3. Parsed derivation `name`

      Returns the raw program name string (not a path).
    '';
    fn = pure.resolveMainProgram;
    tests = {
      "resolves from meta.mainProgram" = {
        args = {
          meta.mainProgram = "myapp";
        };
        expected = "myapp";
      };
      "falls back to pname" = {
        args = {
          pname = "my-script";
          name = "my-script";
          meta = { };
        };
        expected = "my-script";
      };
      "falls back to parsed derivation name" = {
        args = {
          name = "my-script-1.0";
          meta = { };
        };
        expected = "my-script";
      };
    };
  };
}
