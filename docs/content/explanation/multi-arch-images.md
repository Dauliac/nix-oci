+++
title = "Multi-architecture images"
description = "How nix-oci builds OCI images that run on multiple CPU architectures from a single declaration"
+++

# Multi-architecture images

nix-oci supports building OCI images that target multiple CPU
architectures (e.g. `amd64` and `arm64`) from a single container
declaration. A multi-arch image is an
[OCI image index](https://github.com/opencontainers/image-spec/blob/main/image-index.md)
(manifest list) that contains one per-architecture manifest. Container
runtimes automatically select the correct manifest for the host they run
on.

## Two strategies

nix-oci offers two complementary workflows for producing multi-arch
images:

### CI-parallel: native builds on multiple runners

Each CI runner builds the image for its own native architecture, pushes a
temporary per-arch tag, and a final merge step assembles the manifest
list.

```nix
oci.containers.myApp = {
  package = pkgs.hello;
  registry = "ghcr.io/myorg";
  tags = [ "1.0.0" "latest" ];
  multiArch.systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];
};
```

This produces:

| Flake output | Purpose |
|---|---|
| `oci-push-tmp-myApp-amd64` | Push the amd64 image with a temporary tag |
| `oci-push-tmp-myApp-arm64` | Push the arm64 image with a temporary tag |
| `oci-merge-myApp` | Create the manifest list and tag it |

A typical CI pipeline runs `oci-push-tmp-*` in parallel on native
runners, then runs `oci-merge-*` once all runners finish pushing.

See the [CI multi-arch example](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/ci-multi-arch-01.nix)
and the [CI multi-arch with custom tags example](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/ci-multi-arch-custom-tags-01.nix).

### Cross-build: all arches from a single machine

When `crossBuild.enable = true`, non-native architectures are
cross-compiled on the current host using Nix's `pkgsCross`
infrastructure. The result is a single OCI directory layout containing
the manifest list -- no registry or merge step needed.

```nix
oci.containers.myApp = {
  package = pkgs.hello;
  registry = "localhost:5000";
  tags = [ "1.0.0" "latest" ];
  multiArch = {
    systems = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    crossBuild.enable = true;
  };
};
```

This produces:

| Flake output | Purpose |
|---|---|
| `oci-multiarch-myApp` | OCI directory layout with the manifest list |
| `oci-push-multiarch-myApp` | Push the multi-arch image to a registry |

See the [cross-build example](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/cross-build-01.nix)
and the [cross-build with dependencies example](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/cross-build-with-deps-01.nix).

## Automatic package inference

For both strategies, nix-oci automatically resolves cross-compiled
packages via `pkgsCross`. When the container declares
`package = pkgs.hello`, nix-oci infers the arm64 variant as
`pkgs.pkgsCross.aarch64-multiplatform.hello` -- no manual `archConfigs`
needed.

nix-oci infers dependencies listed in `dependencies` the same way. Any
dependency whose `pname` does not match a `pkgsCross` attribute is
silently dropped for that architecture.

## Manual overrides with archConfigs

When auto-inference fails (e.g. custom derivations, `writeShellApplication`,
or packages with a different attribute name in `pkgsCross`), override the
package per-architecture:

```nix
oci.containers.myApp = {
  package = myScript;
  multiArch = {
    systems = [ "x86_64-linux" "aarch64-linux" ];
    crossBuild.enable = true;
  };
  archConfigs."aarch64-linux".package = myScriptArm;
};
```

See the [cross-build with writeShellApplication example](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/cross-build-write-shell-01.nix).

## Supported architectures

| Nix system | OCI architecture | pkgsCross attribute |
|---|---|---|
| `x86_64-linux` | `amd64` | `gnu64` |
| `aarch64-linux` | `arm64` | `aarch64-multiplatform` |
| `armv7l-linux` | `arm/v7` | `armv7l-hf-multiplatform` |
| `riscv64-linux` | `riscv64` | `riscv64` |

## When to use which strategy

| | CI-parallel | Cross-build |
|---|---|---|
| **Build speed** | Fast -- native compilation on each runner | Slower -- cross-compilation overhead |
| **CI infrastructure** | Needs runners for each architecture | Single runner is enough |
| **Registry required** | Yes (temporary tags) | No (local OCI directory) |
| **Best for** | Production CI pipelines with multi-arch runners | Development, testing, single-runner setups |

## Options reference

See the [flake-parts option reference](../reference/flake-parts-options.html) for
default values and full type details.

| Option | Description |
|---|---|
| [`multiArch.systems`](../reference/flake-parts-options.html) | Target architectures (non-empty enables multi-arch) |
| [`multiArch.crossBuild.enable`](../reference/flake-parts-options.html) | Cross-compile all arches locally |
| [`multiArch.tempTagPrefix`](../reference/flake-parts-options.html) | Prefix for temporary per-arch tags (CI workflow) |
| [`archConfigs.<system>.package`](../reference/flake-parts-options.html) | Per-arch package override |
| [`archConfigs.<system>.dependencies`](../reference/flake-parts-options.html) | Per-arch dependencies override |

## All multi-arch examples

- [CI multi-arch](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/ci-multi-arch-01.nix) -- parallel native builds + merge
- [CI multi-arch with custom tags](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/ci-multi-arch-custom-tags-01.nix) -- multiple tags on the manifest list
- [CI multi-arch single system](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/ci-multi-arch-single-system-01.nix) -- start with one arch, add more later
- [Cross-build](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/cross-build-01.nix) -- basic cross-compilation
- [Cross-build with dependencies](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/cross-build-with-deps-01.nix) -- auto-inferred cross deps
- [Cross-build jq](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/cross-build-jq-01.nix) -- real-world package
- [Cross-build non-root](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/cross-build-non-root-01.nix) -- multi-arch with user/labels
- [Cross-build writeShellApplication](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/cross-build-write-shell-01.nix) -- manual archConfigs override
- [Single extra arch](https://github.com/Dauliac/nix-oci/blob/main/examples/flake/multi-arch/single-extra-arch-01.nix) -- add arm64 to an amd64-native build
