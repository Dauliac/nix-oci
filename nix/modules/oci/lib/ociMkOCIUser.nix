# Derive container user from isRoot flag or explicit name
{ lib, ... }:
{
  nix-lib.lib.oci.mkOCIUser = {
    type = lib.types.functionTo lib.types.str;
    description = "Derive container user from isRoot flag or explicit name";
    fn =
      {
        isRoot,
        name,
      }:
      if isRoot then
        "root"
      else if name != null && name != "" then
        name
      else
        throw "No user given and impossible to infer it from name or isRoot";
    tests = {
      "returns root when isRoot is true" = {
        args = {
          isRoot = true;
          name = "someuser";
        };
        expected = "root";
      };
      "returns name when isRoot is false" = {
        args = {
          isRoot = false;
          name = "appuser";
        };
        expected = "appuser";
      };
    };
  };
}
