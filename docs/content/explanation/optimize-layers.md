+++
title = "Optimized layer sharing"
description = "How store-path popularity-based layering shares layers between containers"
+++

# Optimized layer sharing

nix-oci can split your container into multiple OCI layers using a
**store-path popularity algorithm**, so that images sharing common
dependencies automatically share layers in the registry.

## The problem

A naive Nix-built container puts every store path into a single layer.
When you push two images that both depend on glibc, openssl, and bash,
the registry stores those bytes twice. Pulls are equally wasteful —
every deploy re-downloads the full image even if only your application
code changed.

## How it works

The layering algorithm (originally described in
[Nix and layered Docker images](https://grahamc.com/blog/nix-and-layered-docker-images)
by Graham Christensen and implemented by
[nix2container](https://github.com/nlewo/nix2container)) works as follows:

1. **Build the dependency graph** of all store paths in the image
2. **Score each path by popularity** — how many other paths reference it,
   weighted by depth in the dependency tree
3. **Sort paths by score** descending — foundational packages (glibc,
   ncurses, openssl) rank highest
4. **Assign paths to layers** — popular paths get their own layer,
   application-specific paths cluster together
5. **Cap at `maxLayers`** (40 by default) to stay within registry limits

Because Nix store paths are immutable and content-addressed, two images
that share the same glibc store path produce byte-identical layers.
The registry deduplicates them automatically.

### Real-world impact

In the [original blog post](https://grahamc.com/blog/nix-and-layered-docker-images),
a PHP image and a MySQL image built with this approach shared **20 layers**.
Push and fetch times improved by an order of magnitude because common
dependencies are uploaded and downloaded only once.

## Enable it

### flake-parts (build-time)

```nix
perSystem = { ... }: {
  oci.containers.my-app = {
    package = pkgs.hello;
    optimizeLayers = true;
  };
};
```

### Deploy modules (NixOS / Home Manager / system-manager)

Layer optimization is **enabled by default** for deploy containers
(set in `_defaults.nix`). You can disable it explicitly:

```nix
oci.containers.my-app = {
  package = pkgs.hello;
  optimizeLayers = false; # default is true for deploy
};
```

## How dependencies get their own layer

When `optimizeLayers` is true and `dependencies` is non-empty, nix-oci
creates a separate cached layer for dependencies using `nix2container.buildLayer`
with `maxLayers = 80`. This means your runtime libraries (bash, coreutils, …)
live in stable layers that rarely change, while your application package
gets its own thin layer that rebuilds fast.

```nix
oci.containers.my-app = {
  package = pkgs.myApp;
  dependencies = with pkgs; [ bashInteractive coreutils cacert ];
  optimizeLayers = true;
};
```

With this setup:
- **Layer 1–N**: shared foundational paths (glibc, gcc-libs, …)
- **Layer N+1**: your dependencies (bash, coreutils, cacert)
- **Top layer**: your application binary

Only the top layer changes on each rebuild.

## Further reading

- [Nix and layered Docker images](https://grahamc.com/blog/nix-and-layered-docker-images) — the original popularity algorithm
- [nix2container](https://github.com/nlewo/nix2container) — the backend that implements layering
- [Nix & Docker: Layer explicitly without duplicate packages](https://blog.eigenvalue.net/2023-nix2container-everything-once/) — avoiding duplicate store paths in explicit layers
- [Building container images with Nix](https://lewo.abesis.fr/posts/nix-build-container-image/) — the foundational ideas behind nix2container
