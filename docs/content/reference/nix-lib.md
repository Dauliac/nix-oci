+++
title = "nix-lib functions"
+++

# nix-lib Functions

All library functions are exposed as module options under `config.lib.oci.*` (flake-level) or `config.nix-lib.lib.oci.*` (per-system). They are automatically available when you import the nix-oci flake-parts module.

See also:

- [Source: `nix/modules/oci/lib/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/oci/lib)
- [nix2container](https://github.com/nlewo/nix2container) — the backend used to build layers and images

---

## Image Builders

High-level functions that produce complete OCI images.

### `lib.oci.mkOCI`

**Type:** `functionTo package`

Main entry point to build a container with all conditional features (hardening, performance, debug variant, push apps). This is what the module system calls internally for each `oci.containers.<name>`.

### `lib.oci.mkSimpleOCI`

**Type:** `functionTo package`

Build a simple container without Nix support. Uses NixOS eval outputs for all image content.

### `lib.oci.mkNixOCI`

**Type:** `functionTo package`

Build a container with Nix support and build users. Nix-specific additions (nixbld users, nix.conf, nix packages) are handled by the NixOS eval.

### `lib.oci.mkNixOrSimpleOCI`

**Type:** `functionTo package`

Build either a Nix or simple container depending on config. Dispatches to `mkNixOCI` or `mkSimpleOCI` based on `installNix`.

### `lib.oci.mkDebugOCI`

**Type:** `functionTo package`

Build a debug variant that shares layers with the production image. Adds debug tools (bash, curl, coreutils, etc.) in an extra layer on top of the production layer stack.

### `lib.oci.mkDockerArchive`

**Type:** `functionTo package`

Transform a nix2container build into a Docker archive tarball via skopeo.

---

## Layer Composition

Functions for building and composing the deduplicated layer stack.

### `lib.oci.mkImageLayers`

**Type:** `functionTo (listOf package)`

Compose the full deduplicated layer stack for an OCI image. Single entry point that defines the layering heuristic: dependencies → application → (optional) debug → (optional) hwcaps.

### `lib.oci.foldImageLayers`

**Type:** `functionTo (listOf package)`

Chain layers with automatic store-path deduplication via fold. Each layer references all prior layers so nix2container excludes already-present store paths.

### `lib.oci.mkDepsLayer`

**Type:** `functionTo attrs`

Build a layer definition for container dependencies. Contains the dependency `buildEnv` with popularity-based splitting (`maxLayers`) for optimal registry caching. Returns a layer-def attrset for use with `foldImageLayers`.

### `lib.oci.mkAppLayer`

**Type:** `functionTo attrs`

Build a layer definition for the application root filesystem. Contains the application's `copyToRoot` (root filesystem, package, etc.). Returns a layer-def attrset for use with `foldImageLayers`.

### `lib.oci.mkDebugLayer`

**Type:** `functionTo attrs`

Build a layer definition for debug tools. Contains debug packages and optionally the entrypoint wrapper. Returns a layer-def attrset for use with `foldImageLayers`.

### `lib.oci.mkHwcapsLayer`

**Type:** `functionTo package`

Build a glibc-hwcaps layer for a specific microarchitecture level. Rebuilds given libraries with `-march=<level>` and installs only their `.so` files into `/lib/glibc-hwcaps/<level>/`. The dynamic linker selects the best available variant at process startup.

---

## Entrypoint & Metadata Derivation

Functions for deriving OCI image metadata from packages and NixOS config.

### `lib.oci.mkContainerEntrypoint`

**Type:** `functionTo package`

Generate an entrypoint wrapper script from systemd service data. Translates the NixOS systemd service definition into a container entrypoint shell script that creates required directories, sets environment, and execs the service.

### `lib.oci.mkOCIEntrypoint`

**Type:** `functionTo (listOf str)`

Derive container entrypoint from package `mainProgram`, `pname`, or derivation name.

### `lib.oci.mkOCIName`

**Type:** `functionTo str`

Derive container name from package `mainProgram`, `pname`, derivation name, or base image name.

### `lib.oci.mkOCITag`

**Type:** `functionTo str`

Derive container tag from package version or base image tag.

---

## Labels

Functions for generating OCI image labels.

### `lib.oci.mkAutoLabels`

**Type:** `functionTo attrs`

Generate automatic OCI labels from container config. Produces labels in 8 categories: OCI standard annotations (`org.opencontainers.image.*`), build info, hardening, Kubernetes PSS, Kubernetes SecurityContext, network, nix identity, and security.

### `lib.oci.mkHardeningLabels`

**Type:** `functionTo attrs`

Generate OCI labels from hardening config. Embeds runtime security hints as labels under `io.github.dauliac.nix-oci.hardening.*`. Deploy modules read these labels and translate them to container runtime flags.

### `lib.oci.mkPerformanceLabels`

**Type:** `functionTo attrs`

Generate OCI labels encoding performance tuning hints under `io.github.dauliac.nix-oci.performance.*`.

---

## Security & Hardening

Functions for generating security profiles and hardened configurations.

### `lib.oci.mkSeccompProfile`

**Type:** `functionTo package`

Generate a seccomp profile JSON from hardening config. Provides three predefined profiles: `strict` (allowlist ~60 essential syscalls), `moderate` (blocklist ~44 dangerous syscalls), and `minimal`.

### `lib.oci.mkLandlockPolicy`

**Type:** `functionTo package`

Generate a Landlock policy JSON. Landlock operates at the VFS/object level using kernel syscalls (`landlock_create_ruleset` → `landlock_add_rule` → `landlock_restrict_self`).

### `lib.oci.mkHardenedConfigs`

**Type:** `functionTo (listOf package)`

Generate hardened `/etc` config files. Produces derivations for hardened configuration files (e.g., `nsswitch.conf`, `resolv.conf`) based on the container's hardening options.

### `lib.oci.mkPodmanPolicy`

**Type:** `functionTo package`

Build podman security policy configuration.

---

## Registry & Push

Functions for pushing images to container registries.

### `lib.oci.mkPushApp`

**Type:** `functionTo package`

Build a `writeShellApplication` that pushes one specific tag of a built OCI image to the configured registry. A push is the natural unit of parallelism — one derivation per tag.

### `lib.oci.mkPushAllTagsApp`

**Type:** `functionTo package`

Push one image with all its tags efficiently. Pushes the primary tag once from the Nix store, then creates additional tags via registry-side copies (no re-upload).

---

## Architecture

Functions for mapping between Nix system strings and OCI platform metadata.

### `lib.oci.archMap`

**Type:** `attrs`

Map from Nix system strings to OCI platform metadata. Each entry has `ociArch`, `crossPkgsAttr`, optional `ociVariant`, and `microarch` with `hwcapsSupported`, `hwcapsLevels`, `marchValues`, `defaultHwcaps`.

### `lib.oci.supportedSystems`

**Type:** `listOf str`

List of Nix system strings with OCI architecture mappings (e.g., `"x86_64-linux"`, `"aarch64-linux"`).

### `lib.oci.systemToOCIArch`

**Type:** `functionTo str`

Convert a Nix system string to its OCI architecture string. Example: `"x86_64-linux"` → `"amd64"`.

### `lib.oci.systemToOCIPlatform`

**Type:** `functionTo str`

Convert a Nix system string to its OCI platform string. Example: `"x86_64-linux"` → `"linux/amd64"`.

---

## Ports

Functions for parsing container port mappings.

### `lib.oci.parseContainerPort`

**Type:** `functionTo str`

Extract the container port from a port mapping string and normalize to OCI `ExposedPorts` format (`"port/proto"`).

- `"8080:8080"` → `"8080/tcp"`
- `"443:443/udp"` → `"443/udp"`
- `"8080"` → `"8080/tcp"` (no host mapping)

### `lib.oci.mkExposedPorts`

**Type:** `functionTo attrs`

Convert a list of port mapping strings to an OCI `ExposedPorts` attrset.

### `lib.oci.parseHostPort`

**Type:** `functionTo int`

Extract the host port (as integer) from a port mapping string.

- `"8080:8080"` → `8080`
- `"9090:8080"` → `9090`
- `"8080"` → `8080` (same as container port)

---

## Nix-in-Container

### `lib.oci.mkNixConfig`

**Type:** `functionTo package`

Build a Nix configuration file (`nix.conf`) for use inside containers with Nix support.

---

## Utilities

### `lib.oci.filterEnabledOutputsSet`

**Type:** `functionTo attrs`

Filter a config attrset to only include items where `subConfig.enabled` is `true`.

### `lib.oci.prefixOutputs`

**Type:** `functionTo attrs`

Add a prefix to all attribute names in a set.

### `lib.oci.mkOCIPulledManifestLockPath`

**Type:** `functionTo path`

Generate the full path for an OCI manifest lock file.

### `lib.oci.mkOCIPulledManifestLockRelativePath`

**Type:** `functionTo str`

Generate relative path for a specific manifest lock file.

### `lib.oci.mkOCIPulledManifestLockRelativeRootPath`

**Type:** `functionTo str`

Get relative root path for manifest locks from flake `self`.

---

## Flake-Level Helpers

These are registered under `config.lib.flake.*` rather than `config.lib.oci.*`.

### `lib.flake.ociMkPerContainerOption`

**Type:** `functionTo unspecified`

Create an option declaration for per-container modules. Implements the flake-parts pattern for per-container configuration, similar to `mkPerSystemOption`.

### `lib.flake.ociMkPerContainerType`

**Type:** `functionTo unspecified`

Create the per-container deferred module type.
