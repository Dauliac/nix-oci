# Shared: layer splitting strategy.
#
# Controls how aggressively nix2container splits store paths into sub-layers
# within each logical layer (deps, app). Only effective when
# optimizeLayers = true.
{ lib, ... }:
let
  example = "minimal";
in
{
  options.layerStrategy = lib.mkOption {
    type = lib.types.enum [
      "minimal"
      "fine-grained"
    ];
    default = "fine-grained";
    description = ''
      Controls how nix2container splits store paths into sub-layers.
      Only effective when `optimizeLayers` is `true`.

      - `"minimal"`: exactly one layer per concern (deps, app).
        Produces 2 total layers. Most predictable cache behaviour --
        adding or removing a dependency only invalidates the deps layer.
        Best for projects with few images where cross-image sharing is
        not a priority.

      - `"fine-grained"`: each logical layer is further split using
        nix2container's store-path popularity algorithm. The deps layer
        gets up to 80 sub-layers, and `buildImage` splits remaining
        paths into up to 40. Foundational packages (glibc, openssl)
        get their own sub-layers and are shared byte-for-byte across
        images in the same registry. Best for registries hosting many
        images with overlapping dependencies.
    '';
    inherit example;
  };
}
