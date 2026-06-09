# OCI mkDepsLayer - Build a layer definition for container dependencies
#
# Returns a layer-def attrset (not a built layer) suitable for use with
# foldImageLayers. Contains the dependency buildEnv with popularity-based
# splitting (maxLayers) for optimal registry caching.
# Shared by mkSimpleOCI, mkNixOCI, and mkImageLayers.
{ lib, ... }:
let
  pure = import ../../../../lib/oci.nix { inherit lib; };
in
{
  config.perSystem =
    {
      pkgs,
      lib,
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
          pure.mkDepsLayer {
            inherit pkgs dependencies layerStrategy;
          };
      };
    };
}
