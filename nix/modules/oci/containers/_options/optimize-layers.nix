# Shared: layer optimization.
#
# Based on the store-path popularity algorithm described in
# https://grahamc.com/blog/nix-and-layered-docker-images
{ lib, ... }:
{
  options.optimizeLayers = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Split container contents into multiple layers using nix2container's
      store-path popularity algorithm for optimal registry caching.

      When enabled, Nix store paths are sorted by how many other paths
      reference them (popularity). Foundational packages (glibc, openssl, …)
      get their own layers while application-specific paths are clustered
      together. Because store paths are immutable and content-addressed,
      images that share common dependencies automatically share layers in
      the registry, dramatically reducing push and pull times.

      See [Nix and layered Docker images](https://grahamc.com/blog/nix-and-layered-docker-images)
      for the original algorithm and [nix2container](https://github.com/nlewo/nix2container)
      for the implementation used here.
    '';
    example = true;
  };
}
