# Merge a base policy directory with extra policy directories via symlinkJoin.
# Returns baseDir unchanged when extraDirs is empty.
{ ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkMergedPolicyDir = {
        type = lib.types.functionTo lib.types.path;
        description = "Merge base + extra policy directories into one via symlinkJoin. Returns baseDir when extraDirs is empty.";
        file = "nix/modules/oci/lib/mkMergedPolicyDir.nix";
        fn =
          {
            name,
            baseDir,
            extraDirs ? [ ],
          }:
          if extraDirs == [ ] then
            baseDir
          else
            pkgs.symlinkJoin {
              name = "merged-policies-${name}";
              paths = [ baseDir ] ++ extraDirs;
            };
      };
    };
}
