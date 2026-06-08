+++
title = "Just-in-time container building"
description = "How nix2container builds OCI images without intermediate archives, reducing store bloat and enabling streaming pushes"
+++

# Just-in-time container building

nix-oci relies on [nix2container](https://github.com/nlewo/nix2container) to
build OCI images using a fundamentally different approach than traditional
tools: layers are never materialized as tar archives in the Nix store.
Instead, they exist as **JSON descriptions** of store paths, and actual
tarballs are generated **just-in-time** — only when loading into a runtime or
pushing to a registry.

## The problem with archive-based builds

Traditional container build tools — whether `docker build` with a Dockerfile
or Nix's built-in `dockerTools.buildImage` — follow the same pattern:

1. Collect the filesystem contents.
2. Write one or more **tar archives** (layers) to disk.
3. Bundle them into an OCI/Docker archive.
4. Push or load that archive.

This creates two problems:

- **Store bloat**: every store path that goes into the image is stored
  *twice* — once as a Nix derivation output and once inside a layer tarball.
  A 500 MB image effectively costs 1 GB of disk.
- **Slow rebuilds**: changing a single dependency forces the entire archive to
  be rebuilt and re-written, even if most layers are identical to the previous
  build.

Nix's `dockerTools.streamLayeredImage` partially addresses this by streaming
the archive instead of writing it to the store, but it still computes every
layer tarball on each invocation and cannot skip layers already present in a
registry.

## How nix2container solves it

nix2container replaces tar archives with lightweight **JSON metadata files**.
A built image in the Nix store is just a few kilobytes of JSON listing:

- The Nix store paths belonging to each layer.
- Pre-computed **digests and diff IDs** for every layer.
- OCI image configuration (entrypoint, env, labels, etc.).

No tar archive is written during `nix build`. The image "recipe" is a
pure Nix derivation that produces only JSON — this is what we mean by
**just-in-time** (or archive-less) container building.

### Streaming push with Skopeo

nix2container ships a small Go library (~250 lines) that plugs into
[Skopeo](https://github.com/containers/skopeo) as a custom `nix:` transport.
When you push an image:

1. Skopeo reads the JSON manifest.
2. For each layer, it checks the **pre-computed digest** against the registry.
   Layers that already exist are skipped entirely — no data is generated or
   transferred.
3. Only missing layers are **tar-archived on the fly** and streamed directly
   to the registry, without touching the local disk.

This makes pushes dramatically faster:

| Operation | `dockerTools.buildImage` | `dockerTools.streamLayeredImage` | **nix2container** |
|---|---|---|---|
| Rebuild + push | ~10 s | ~7.5 s | **~1.8 s** |

*(Benchmarks from the [nix2container README](https://github.com/nlewo/nix2container).)*

### Loading into Docker / Podman

The same principle applies when loading images locally. nix2container
generates `copyToDockerDaemon` and `copyToPodman` scripts that use Skopeo to
stream layers into the local runtime without creating intermediate files.

## Comparison with other Nix container tools

| Tool | Archive in store | Incremental push | Layer optimization |
|---|---|---|---|
| `dockerTools.buildImage` | Yes (full OCI tar) | No | No |
| `dockerTools.buildLayeredImage` | Yes (layer tars) | No | Popularity-based |
| `dockerTools.streamLayeredImage` | No (streamed) | No (recomputes all) | Popularity-based |
| **nix2container** | **No (JSON only)** | **Yes (digest check)** | **Popularity-based** |

### Outside the Nix ecosystem

Other tools that pursue just-in-time or layer-streaming strategies:

- [**ko**](https://ko.build/) — builds Go container images directly from
  source without a Dockerfile; layers are assembled on push.
- [**Jib**](https://github.com/GoogleContainerTools/jib) — builds Java
  container images without Docker, computing layers from build artifacts and
  pushing them individually.
- [**Buildpacks**](https://buildpacks.io/) — auto-detect application type and
  produce images with reusable base layers, though they still write archives
  locally.
- [**Nixery**](https://nixery.dev/) — serves Nix-built images from a registry
  endpoint, computing layers on demand per HTTP request.

nix2container stands out by combining Nix's reproducibility guarantees with
truly archive-less builds: the Nix store only ever contains JSON metadata,
and the actual image bytes are generated at the moment they are needed.

## Why it matters for nix-oci

Because nix-oci uses nix2container as its backend:

- **Minimal store usage** — building dozens of container variants does not
  bloat your Nix store with duplicate tarballs.
- **Fast iteration** — rebuilding after a code change only recomputes the JSON
  manifest; pushing only transfers the changed layer.
- **Efficient CI** — CI runners benefit from smaller caches and shorter push
  times, since unchanged layers are never re-uploaded.
- **Reproducibility** — the JSON manifest is a pure Nix derivation, so the
  image is bit-for-bit reproducible across machines.

## Further reading

- [nix2container](https://github.com/nlewo/nix2container) — the backend powering nix-oci
- [Building container images with Nix](https://lewo.abesis.fr/posts/nix-build-container-image/) — foundational ideas behind the archive-less approach
- [Optimized layer sharing](./optimize-layers.md) — how nix-oci uses popularity-based layering on top of nix2container
