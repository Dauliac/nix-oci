# OCI mkImageLayers - Compose the full layer stack for an OCI image
#
# Single entry point that defines the layering heuristic:
#   1. Dependencies layer (most stable, shared across images)
#   2. Application layer (root filesystem, package)
#   3. Optional debug layer (debug tools, entrypoint wrapper)
#
# All layers are chained via a fold so each layer deduplicates
# store paths already present in earlier layers. The ordering is deliberate:
# foundational deps change least often → best registry cache hit rate.
#
# The `layerStrategy` parameter controls sub-splitting:
#   - "minimal": exactly 1 layer per concern (deps, app, debug)
#   - "fine-grained": deps split into up to 80 sub-layers via popularity
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  config.perSystem =
    {
      lib,
      pkgs,
      config,
      ...
    }:
    let
      ociLib = config.lib.oci or { };
    in
    {
      nix-lib.lib.oci.mkImageLayers = {
        type = lib.types.functionTo (lib.types.listOf lib.types.package);
        description = "Compose the full deduplicated layer stack for an OCI image";
        file = "nix/modules/oci/lib/mkImageLayers.nix";
        fn =
          args@{
            nix2container,
            layerStrategy ? "fine-grained",
            prependLayerDefs ? [ ],
            prependBuiltLayers ? [ ],
            dependencies ? [ ],
            copyToRoot ? [ ],
            rootPaths ? copyToRoot,
            debug ? null,
            ...
          }:
          pure.mkImageLayers {
            inherit
              nix2container
              pkgs
              layerStrategy
              prependLayerDefs
              prependBuiltLayers
              dependencies
              rootPaths
              ;
            mkDebugLayer = ociLib.mkDebugLayer or null;
            inherit debug;
          };
      };
    };
}
