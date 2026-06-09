# OCI mkDebugLayer - Build a layer definition for debug tools
#
# Returns a layer-def attrset (not a built layer) suitable for use with
# foldImageLayers. Contains debug packages (bash, curl, coreutils, etc.)
# and optionally the entrypoint wrapper. When folded after production layers,
# only debug-specific store paths end up in this layer.
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkDebugLayer = {
        type = lib.types.functionTo lib.types.attrs;
        description = "Build a layer definition for debug tools (for use with foldImageLayers)";
        file = "nix/modules/oci/lib/mkDebugLayer.nix";
        fn =
          {
            packages,
            entrypointWrapper ? null,
          }:
          {
            copyToRoot = [
              (pkgs.buildEnv {
                name = "debug";
                paths = packages ++ lib.optional (entrypointWrapper != null) entrypointWrapper;
                pathsToLink = [
                  "/bin"
                  "/lib"
                  "/etc"
                ];
                ignoreCollisions = true;
              })
            ];
          };
      };
    };
}
