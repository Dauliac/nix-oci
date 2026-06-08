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
{
  config.perSystem =
    {
      lib,
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
        fn =
          {
            nix2container,
            layerStrategy ? "fine-grained",
            prependLayerDefs ? [ ],
            prependBuiltLayers ? [ ],
            dependencies ? [ ],
            copyToRoot ? [ ],
            debug ? null,
          }:
          let
            depsLayerDefs =
              if dependencies != [ ] then
                [ (ociLib.mkDepsLayer { inherit dependencies layerStrategy; }) ]
              else
                [ ];

            appLayerDefs =
              if copyToRoot != [ ] then [ (ociLib.mkAppLayer { inherit copyToRoot; }) ] else [ ];

            debugLayerDefs =
              if debug != null then
                [
                  (ociLib.mkDebugLayer {
                    inherit (debug) packages;
                    entrypointWrapper = debug.entrypointWrapper or null;
                  })
                ]
              else
                [ ];

            allLayerDefs = prependLayerDefs ++ depsLayerDefs ++ appLayerDefs ++ debugLayerDefs;

            mergeToLayer =
              priorLayers: layerDef:
              let
                layer = nix2container.buildLayer (layerDef // { layers = priorLayers; });
              in
              priorLayers ++ [ layer ];
          in
          lib.foldl mergeToLayer prependBuiltLayers allLayerDefs;
      };
    };
}
