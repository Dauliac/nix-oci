# Add prefix to all attribute names in a set
{ lib, ... }:
let
  inherit (lib) attrsets foldl';
in
{
  nix-lib.lib.oci.prefixOutputs = {
    type = lib.types.functionTo lib.types.attrs;
    description = "Add a prefix to all attribute names in a set";
    fn =
      {
        prefix,
        set,
      }:
      foldl' (
        acc: id:
        acc
        // {
          "${prefix}${id}" = set.${id};
        }
      ) { } (attrsets.attrNames set);
    tests = {
      "prefixes all keys in set" = {
        args = {
          prefix = "oci-";
          set = {
            foo = 1;
            bar = 2;
          };
        };
        expected = {
          "oci-foo" = 1;
          "oci-bar" = 2;
        };
      };
      "handles empty set" = {
        args = {
          prefix = "test-";
          set = { };
        };
        expected = { };
      };
    };
  };
}
