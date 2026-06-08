+++
title = "Optimized layer sharing"
description = "How the layering heuristic deduplicates store paths across production and debug images"
+++

# Optimized layer sharing

nix-oci can split your container into multiple OCI layers using a
**store-path popularity algorithm** combined with **fold-based
deduplication**, so that images sharing common dependencies — including
production and debug variants — automatically share layers in the
registry.

## The problem

A naive Nix-built container puts every store path into a single layer.
When you push two images that both depend on glibc, openssl, and bash,
the registry stores those bytes twice. Pulls are equally wasteful —
every deploy re-downloads the full image even if only your application
code changed.

```mermaid
graph LR
    subgraph "Naive: no layer sharing"
        direction TB
        A1["Image A<br/>glibc + openssl + bash + app-a"]
        B1["Image B<br/>glibc + openssl + bash + app-b"]
    end
    A1 -. "duplicated bytes" .-> B1
```

The problem gets worse with **debug images**: a debug variant typically
adds a handful of tools (curl, coreutils, an entrypoint wrapper) on top
of an otherwise identical production image. Without explicit layer
sharing, the entire image is rebuilt from scratch and shares zero bytes
with production in the registry.

## The layering heuristic

nix-oci applies a two-level strategy when `optimizeLayers = true`:

### Level 1 — nix2container's popularity algorithm

Each `buildLayer` / `buildImage` call with a `maxLayers` cap triggers
nix2container's internal store-path popularity algorithm (originally
described in [Nix and layered Docker images](https://grahamc.com/blog/nix-and-layered-docker-images)
by Graham Christensen):

```mermaid
flowchart TD
    A["All store paths in the layer"] --> B["Build dependency graph"]
    B --> C["Score each path by popularity<br/>(reference count × depth weight)"]
    C --> D["Sort descending<br/>glibc > ncurses > openssl > app"]
    D --> E["Assign to sub-layers<br/>popular paths → own layer<br/>app paths → clustered"]
    E --> F["Cap at maxLayers budget"]
```

Because Nix store paths are immutable and content-addressed, two images
that share the same glibc store path produce byte-identical layers.
The registry deduplicates them automatically.

### Level 2 — fold-based cross-layer deduplication

nix2container builds each layer independently by default. When you have
multiple explicit layers (deps, app, debug), shared store paths like
glibc can end up **duplicated** across layers — this was documented in
[Nix & Docker: Layer explicitly without duplicate packages](https://blog.eigenvalue.net/2023-nix2container-everything-once/).

nix-oci solves this with a **fold pattern**: layers are built in order,
and each layer references all prior layers via the `layers` attribute.
nix2container then excludes any store path already present in a
predecessor:

```mermaid
flowchart LR
    subgraph "Fold chain"
        direction LR
        L0["[ ]"] -->|"+ deps def"| L1["[deps]"]
        L1 -->|"+ app def"| L2["[deps, app]"]
        L2 -->|"+ debug def"| L3["[deps, app, debug]"]
    end
    L1 -.- N1["app excludes<br/>deps store paths"]
    L2 -.- N2["debug excludes<br/>deps + app store paths"]
```

```nix
# Simplified — see mkImageLayers.nix for the real implementation
foldImageLayers = { nix2container, layerDefs }:
  let
    mergeToLayer = priorLayers: layerDef:
      let
        layer = nix2container.buildLayer (layerDef // { layers = priorLayers; });
      in
        priorLayers ++ [ layer ];
  in
    lib.foldl mergeToLayer [] layerDefs;
```

The result: **zero duplicated store paths** across layers.

## Layer strategies

The `layerStrategy` option controls how aggressively nix2container
splits store paths into sub-layers. It only takes effect when
`optimizeLayers = true`.

### `"fine-grained"` (default)

Each logical layer is further split using the popularity algorithm.
Best for registries hosting many images with overlapping dependencies.

```mermaid
flowchart TD
    subgraph prod ["Production image (fine-grained)"]
        direction TB
        app["App layer"]
        deps["Deps layer<br/>(up to 80 sub-layers)"]
        app --> deps
    end
    deps -->|"deduplicates against"| buildimage["buildImage maxLayers = 40<br/>(remaining paths)"]

    style app fill:#f9e2ae,stroke:#e6a800,color:#000
    style deps fill:#a6da95,stroke:#40a02b,color:#000
    style buildimage fill:#ced4da,stroke:#868e96,color:#000
```

| Scope | `maxLayers` |
|---|---|
| Dependencies layer | 80 |
| `buildImage` (remaining) | 40 |
| Total budget | ~124 (under 127 OCI limit) |

### `"minimal"`

Exactly one layer per concern — no sub-splitting. Most predictable
cache behaviour: adding a dependency only invalidates the deps layer.
Best for projects with few images.

```mermaid
flowchart TD
    subgraph prod ["Production image (minimal)"]
        direction TB
        app["App layer<br/>(single layer)"]
        deps["Deps layer<br/>(single layer)"]
        app --> deps
    end

    style app fill:#f9e2ae,stroke:#e6a800,color:#000
    style deps fill:#a6da95,stroke:#40a02b,color:#000
```

| Scope | Layers |
|---|---|
| Dependencies | exactly 1 |
| Application | exactly 1 |
| Debug (if enabled) | exactly 1 |
| Total | 2–3 |

## The layer stack

### Production image

```mermaid
flowchart TD
    subgraph prod ["Production image"]
        direction TB
        app["App layer<br/>(package, shadow, configs)"]
        deps["Deps layer<br/>(bash, coreutils, cacert…)"]
        app --> deps
    end

    style app fill:#f9e2ae,stroke:#e6a800,color:#000
    style deps fill:#a6da95,stroke:#40a02b,color:#000
```

- **App layer** — changes on each rebuild
- **Deps layer** — stable, shared across images

For Nix-enabled containers (`installNix = true`), a **Nix layer** is
prepended and all subsequent layers deduplicate against it:

```mermaid
flowchart TD
    subgraph nixprod ["Nix-enabled production image"]
        direction TB
        app["App layer"]
        deps["Deps layer"]
        configs["Config files layer"]
        nix["Nix layer<br/>(nix, bash, coreutils, nixbld users)"]
        app --> deps --> configs --> nix
    end

    style app fill:#f9e2ae,stroke:#e6a800,color:#000
    style deps fill:#a6da95,stroke:#40a02b,color:#000
    style configs fill:#b4befe,stroke:#7287fd,color:#000
    style nix fill:#89b4fa,stroke:#1e66f5,color:#000
```

### Debug image (layer sharing with production)

When `debug.enabled = true` and `optimizeLayers = true`, the debug image
is built **on top of** the production layer stack — not rebuilt from
scratch:

```mermaid
flowchart TD
    subgraph prod ["Production"]
        direction TB
        pa["App layer"]
        pd["Deps layer"]
        pa --> pd
    end
    subgraph debug ["Debug"]
        direction TB
        dbg["Debug layer<br/>(curl, strace…)"]
        da["App layer"]
        dd["Deps layer"]
        dbg --> da --> dd
    end

    pd -. "byte-identical" .-> dd
    pa -. "byte-identical" .-> da

    style pa fill:#f9e2ae,stroke:#e6a800,color:#000
    style pd fill:#a6da95,stroke:#40a02b,color:#000
    style da fill:#f9e2ae,stroke:#e6a800,color:#000
    style dd fill:#a6da95,stroke:#40a02b,color:#000
    style dbg fill:#f5c2e7,stroke:#ea76cb,color:#000
```

The deps and app layers are **byte-identical** between production and
debug. The debug layer is folded after the production layers, so it only
contains store paths **not already present** in deps or app. Pushing
both images to the same registry uploads the shared layers once.

## Enable it

### flake-parts (build-time)

```nix
perSystem = { ... }: {
  oci.containers.my-app = {
    package = pkgs.hello;
    optimizeLayers = true;
    layerStrategy = "minimal"; # or "fine-grained" (default)
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
  layerStrategy = "minimal"; # or "fine-grained" (default)
};
```

## Example: production + debug sharing

```nix
oci.containers.my-app = {
  package = pkgs.myApp;
  dependencies = with pkgs; [ bashInteractive coreutils cacert ];
  optimizeLayers = true;
  layerStrategy = "fine-grained";

  debug.enabled = true;
  debug.packages = with pkgs; [ curl strace ];
};
```

With this setup:
- **Production image**: deps layer (glibc, bash, coreutils…) + app layer (myApp)
- **Debug image**: same deps layer + same app layer + thin debug layer (curl, strace)
- Only the debug layer is unique to the debug image — everything else is shared

## Lib function composition

```mermaid
flowchart TD
    mkDepsLayer["mkDepsLayer<br/>layer-def for dependencies"]
    mkAppLayer["mkAppLayer<br/>layer-def for app root"]
    mkDebugLayer["mkDebugLayer<br/>layer-def for debug tools"]
    foldImageLayers["foldImageLayers<br/>core fold with deduplication"]
    mkImageLayers["mkImageLayers<br/>orchestrator"]

    mkDepsLayer --> mkImageLayers
    mkAppLayer --> mkImageLayers
    mkDebugLayer --> mkImageLayers
    mkImageLayers --> foldImageLayers

    mkSimpleOCI["mkSimpleOCI"] -.->|"delegates to"| mkImageLayers
    mkNixOCI["mkNixOCI"] -.->|"delegates to"| mkImageLayers
    mkDebugOCI["mkDebugOCI"] -.->|"extends with debug"| mkImageLayers

    style mkImageLayers fill:#a6da95,stroke:#40a02b,color:#000
    style foldImageLayers fill:#89b4fa,stroke:#1e66f5,color:#000
```

`mkImageLayers` is the single entry point that defines the ordering
heuristic. Both `mkSimpleOCI` and `mkNixOCI` delegate to it, and
`mkDebugOCI` extends its output with a debug layer. The deploy module
has its own equivalent functions in `ociLib` following the same pattern.

## Further reading

- [Nix and layered Docker images](https://grahamc.com/blog/nix-and-layered-docker-images) — the original popularity algorithm
- [nix2container](https://github.com/nlewo/nix2container) — the backend that implements layering
- [Nix & Docker: Layer explicitly without duplicate packages](https://blog.eigenvalue.net/2023-nix2container-everything-once/) — the fold pattern for cross-layer deduplication
- [Building container images with Nix](https://lewo.abesis.fr/posts/nix-build-container-image/) — the foundational ideas behind nix2container
