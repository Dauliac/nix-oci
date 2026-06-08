# OCI mkDepsLayer - Build a layer definition for container dependencies
#
# Returns a layer-def attrset (not a built layer) suitable for use with
# foldImageLayers. Contains the dependency buildEnv with popularity-based
# splitting (maxLayers) for optimal registry caching.
# Shared by mkSimpleOCI, mkNixOCI, and mkImageLayers.
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      config,
      ...
    }:
    {
      nix-lib.lib.oci.mkDepsLayer = {
        type = lib.types.functionTo lib.types.attrs;
        description = "Build a layer definition for container dependencies (for use with foldImageLayers)";
        fn =
          {
            dependencies,
            layerStrategy ? "fine-grained",
          }:
          {
            copyToRoot = [
              (pkgs.buildEnv {
                name = "deps";
                paths = dependencies;
                pathsToLink = [
                  "/bin"
                  "/lib"
                  "/etc"
                ];
                ignoreCollisions = true;
              })
            ];
          }
          // lib.optionalAttrs (layerStrategy == "fine-grained") {
            maxLayers = 80;
          };
      };
    };
}
