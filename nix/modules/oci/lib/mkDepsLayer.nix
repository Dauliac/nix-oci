# OCI mkDepsLayer - Build a cached layer from container dependencies
#
# Separates dependencies into their own nix2container layer with
# popularity-based splitting (maxLayers) for optimal registry caching.
# Shared by mkSimpleOCI and mkNixOCI when optimizeLayers is enabled.
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
        type = lib.types.functionTo lib.types.package;
        description = "Build a cached layer from container dependencies";
        fn =
          {
            perSystemConfig,
            dependencies,
          }:
          perSystemConfig.packages.nix2container.buildLayer {
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
            maxLayers = 80;
          };
      };
    };
}
