# OCI foldImageLayers - Chain layers with automatic store-path deduplication
#
# Each layer in the list references all prior layers via the `layers` attribute,
# so nix2container automatically excludes store paths already present in earlier
# layers. This is the fold pattern described in:
# https://blog.eigenvalue.net/2023-nix2container-everything-once/
{ lib, ... }:
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci.foldImageLayers = {
        type = lib.types.functionTo (lib.types.listOf lib.types.package);
        description = "Chain layers with automatic store-path deduplication via fold";
        fn =
          {
            nix2container,
            layerDefs,
          }:
          let
            mergeToLayer =
              priorLayers: layerDef:
              let
                layer = nix2container.buildLayer (layerDef // { layers = priorLayers; });
              in
              priorLayers ++ [ layer ];
          in
          lib.foldl mergeToLayer [ ] layerDefs;
      };
    };
}
