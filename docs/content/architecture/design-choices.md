+++
title = "Design choices and best practices"
description = "Overview of nix-oci's opinionated defaults: secure, minimal, reproducible, self-describing containers"
+++

# Design choices and best practices

nix-oci ships with a set of opinionated defaults that guide users toward
production-ready containers without requiring explicit configuration. Every
default can be overridden, but the out-of-the-box experience aims to
produce images that are **secure**, **minimal**, **reproducible**, and
**self-describing**.

Each topic has its own detailed page:

- [Security defaults](./security-defaults.md): non-root by default, distroless by construction, security tooling, bit-for-bit reproducibility
- [Automatic OCI labels](./automatic-labeling.md): OCI standard annotations, build metadata, hardening hints, Kubernetes SecurityContext/PSS, network ports, Nix identity, nixpkgs security
- [Automatic metadata derivation](./automatic-metadata.md): healthchecks, stop signals, working directories, volume declarations from NixOS services
- [Multi-architecture images](./multi-arch-images.md): CI-parallel native builds or single-machine cross-compilation for multi-arch OCI manifests
- [OCI standards compliance](./oci-standards-compliance.md): layer changesets, media types, file attributes, image configuration, and how nix-oci aligns with the OCI image specification
- [NixOS and home-manager in containers](./nixos-home-manager-integration.md): why NixOS module evaluation and home-manager dotfiles produce declarative, introspectable, comfortable containers
- [Container sandbox](./sandbox.md): rootless, isolated shell into any container's filesystem using bubblewrap

The rest of this page covers the remaining design choices that don't
warrant a full page.

## FHS-structured root filesystem

Container root filesystems follow the [Filesystem Hierarchy Standard](https://refspecs.linuxfoundation.org/FHS_3.0/fhs-3.0.html)
layout. The `mkRoot` function uses `pkgs.buildEnv` with
`pathsToLink = ["/bin" "/lib" "/etc"]` to assemble a conventional
directory tree.

### Why it matters

- **Compatibility**: most runtime tools (shells, interpreters, linked
  libraries) expect binaries in `/bin` and libraries in `/lib`. FHS
  compliance avoids mysterious `ENOENT` errors.
- **OCI conventions**: nix-oci sets container entrypoints as absolute paths
  (`/bin/myapp`), matching what operators expect from `docker inspect`.
- **Nix store paths stay hidden**: the `buildEnv` symlinks Nix store
  paths into FHS locations, so the container looks like a standard Linux
  filesystem to inspection tools, log aggregators, and security
  scanners.
- **CA certificates**: every container includes `pkgs.cacert`, placing
  the Mozilla CA bundle at `/etc/ssl/certs/ca-bundle.crt`. TLS works
  out of the box, with no need to manually add certificates or set
  `SSL_CERT_FILE`.

## Automatic naming from packages

Container name and tag are **derived from the package** rather than
specified manually:

### Name resolution chain

1. `package.meta.mainProgram` (preferred, lowercase)
2. `package.pname`
3. Parsed derivation name (`builtins.parseDrvName`)
4. Base image name (when using `fromImage`)

### Tag resolution chain

1. `package.version` (preferred)
2. Base image tag (when using `fromImage`)
3. Fallback (see [`tag`](../reference/flake-parts-options.html) option reference)

### Why it matters

- **Single source of truth**: the package already carries its name and
  version. Duplicating that information in container options is
  error-prone, especially when bumping versions.
- **Consistent naming**: `meta.mainProgram` is the canonical binary
  name in Nix. Using it as the image name means
  `docker run myapp:1.2.3` matches the binary inside the container.
- **Registry hygiene**: tags derived from package versions make it
  trivial to trace a running container back to its source.
- **Always lowercase**: nix-oci forces the name to lowercase via
  `lib.strings.toLower`, since OCI image names must be lowercase.

All automatic derivation can be overridden by setting `name` and `tag`
explicitly.

## Automatic entrypoint from packages

The entrypoint follows the same resolution chain as the name:

1. `package.meta.mainProgram` -> `["/bin/myapp"]`
2. `package.pname` -> `["/bin/my-script"]`
3. Parsed derivation name -> `["/bin/my-script"]`

### Why it matters

- **Zero configuration for common cases**: a `package = pkgs.caddy;`
  container automatically gets `entrypoint = ["/bin/caddy"]`, with no
  manual wiring needed.
- **Convention over configuration**: the Nix ecosystem already uses
  `meta.mainProgram` to identify the primary binary. nix-oci reuses
  that convention rather than inventing its own.
- **Explicit override**: when the entrypoint needs flags or a wrapper
  script, set `entrypoint` directly; nix-oci skips automatic derivation
  when the option is non-empty.

## Layer optimization: most stable first

When `optimizeLayers = true`, nix-oci splits the image into a **stack of
layers ordered by change frequency** (most stable at the bottom):

1. **Deps layer**: runtime libraries and dependencies
2. **App layer**: the package, shadow setup, config files

Each layer references its predecessors, and nix2container excludes any
store path already present in an earlier layer. This **fold-based
deduplication** guarantees zero duplicated store paths across layers.

Two strategies control sub-splitting granularity:

| Strategy | Deps sub-layers | Total layers | Best for |
|---|---|---|---|
| `"fine-grained"` ([default](../reference/flake-parts-options.html)) | Up to 80 | ~124 | Registries with many overlapping images |
| `"minimal"` | 1 | 2-3 | Few images, predictable caching |

See [Optimized layer sharing](./optimize-layers.md) for the full
explanation.

## Environment variable dual-write

nix-oci writes environment variables declared in `environment` to **both**
the OCI image config (`Env`) and the container runner service (Docker/Podman
`--env` flags). See [Container metadata wiring](./container-metadata-wiring.md)
for details.

### Why it matters

- **Inspectability**: `docker inspect` and `skopeo inspect` show the
  variables baked into the image, making it straightforward to audit what a
  container will receive.
- **Runtime override**: operators can still override variables at
  deploy time; the runner service flags take precedence over
  image-level `Env`.

## Port wiring across layers

A single `ports = ["8080:8080"]` declaration flows to four destinations:

1. **OCI ExposedPorts**: image metadata
2. **Runner service**: Docker/Podman port mapping
3. **NixOS firewall**: `allowedTCPPorts` (NixOS deploy only)
4. **Home-manager runner**: Podman port mapping

### Why it matters

- **One declaration, no drift**: declaring a port once prevents the
  common failure mode where the image exposes a port but the firewall
  blocks it (or vice versa).
- **Secure by default**: nix-oci opens firewall rules automatically only
  for declared ports; no need to remember to update
  `networking.firewall` separately.

## Testing as Nix derivations

nix-oci defines container tests declaratively and executes them as reproducible
Nix derivations:

| Tool | Purpose |
|---|---|
| **Container Structure Test** | File existence, command output, metadata assertions |
| **dive** | Layer efficiency analysis |
| **dgoss** | Docker + goss behavioral tests (optional hermetic mode) |

Tests run in the Nix sandbox (or optionally with podman for dgoss),
ensuring they are reproducible across machines and CI environments.

## Summary of defaults

| Option | Rationale |
|---|---|
| [`isRoot`](../reference/flake-parts-options.html) | Security (build) vs. pragmatism ([deploy](../reference/nixos-options.html)) |
| [`optimizeLayers`](../reference/flake-parts-options.html) | Speed (build) vs. efficiency ([deploy](../reference/nixos-options.html)) |
| [`layerStrategy`](../reference/flake-parts-options.html) | Maximum cross-image sharing |
| [`user`](../reference/flake-parts-options.html) | Overridden by `isRoot` logic |
| [`tag`](../reference/flake-parts-options.html) | Overridden by package version |
| [`entrypoint`](../reference/flake-parts-options.html) | Auto-derived from package |
| [`autoStart`](../reference/nixos-options.html) | Load image only; explicit opt-in to run |
| [`healthcheck`](../reference/flake-parts-options.html) | Service adapters derive from NixOS config |
| [`stopSignal`](../reference/flake-parts-options.html) | Correct graceful shutdown per service |
| [`workingDir`](../reference/flake-parts-options.html) | systemd -> dataDir -> home |
| [`declaredVolumes`](../reference/flake-parts-options.html) | systemd StateDirectory/RuntimeDirectory |
| [`autoLabels`](../reference/flake-parts-options.html) | Self-describing images |
| CA certificates | TLS works out of the box |

See the [flake-parts](../reference/flake-parts-options.html),
[NixOS](../reference/nixos-options.html), and
[Home Manager](../reference/home-manager-options.html) option references
for default values in each context.

## Further reading

- [Security defaults](./security-defaults.md): non-root, distroless, hardening, reproducibility
- [Automatic OCI labels](./automatic-labeling.md): OCI annotations, K8s PSS, Kyverno integration
- [Automatic metadata derivation](./automatic-metadata.md): healthcheck, stopSignal, workingDir, volumes
- [Archive-less container building](./archive-less-container-building.md): how nix2container avoids tar archives
- [Optimized layer sharing](./optimize-layers.md): the two-level layering heuristic
- [Container metadata wiring](./container-metadata-wiring.md): how options flow to OCI config, services, and firewall
- [Multi-architecture images](./multi-arch-images.md): CI-parallel or cross-build multi-arch workflows
