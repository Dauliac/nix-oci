# OCI mkAppLayer - Build a layer definition for the application root filesystem
#
# Returns a layer-def attrset (not a built layer) suitable for use with
# foldImageLayers. Contains the application's copyToRoot (root filesystem,
# package, etc.) so it can be deduplicated against prior layers.
{ lib, ... }:
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci.mkAppLayer = {
        type = lib.types.functionTo lib.types.attrs;
        description = "Build a layer definition for the application root filesystem (for use with foldImageLayers)";
        fn =
          { copyToRoot }:
          {
            inherit copyToRoot;
          };
      };
    };
}
