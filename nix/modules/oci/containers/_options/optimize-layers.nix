# Shared: layer optimization.
#
# Two-level heuristic:
#   1. nix2container popularity algorithm (maxLayers budget per layer)
#   2. Fold-based cross-layer deduplication (each layer excludes prior store paths)
#
# References:
#   - https://grahamc.com/blog/nix-and-layered-docker-images
#   - https://blog.eigenvalue.net/2023-nix2container-everything-once/
{ lib, ... }:
{
  options.optimizeLayers = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Split container contents into deduplicated layers for optimal
      registry caching. Uses a two-level heuristic:

      **Level 1 -- popularity-based splitting.** Within each layer,
      nix2container's store-path popularity algorithm sorts paths by
      how many other paths reference them. Foundational packages
      (glibc, openssl, …) get their own sub-layers; application-specific
      paths cluster together. Capped by a `maxLayers` budget per layer.

      **Level 2 -- fold-based cross-layer deduplication.** Layers are
      built in a chain where each layer references all predecessors.
      nix2container excludes any store path already present in an
      earlier layer, eliminating duplication across explicit layers.

      The resulting layer stack (most stable first):
      - Deps layer (runtime libraries, `maxLayers = 80` when fine-grained)
      - App layer (package, shadow, configs)

      Use `layerStrategy` to control sub-splitting granularity:
      `"fine-grained"` (default) for maximum cross-image sharing,
      `"minimal"` for exactly one layer per concern.

      See [Nix and layered Docker images](https://grahamc.com/blog/nix-and-layered-docker-images)
      for the original algorithm and [nix2container](https://github.com/nlewo/nix2container)
      for the implementation used here.
    '';
    example = true;
  };
}
