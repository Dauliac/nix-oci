+++
title = "Getting Started"
description = "Build and deploy your first OCI container with nix-oci"

+++

# Getting Started

This tutorial walks you through building your first container image,
then deploying it on NixOS, all from Nix.

## Prerequisites

- A flake-based Nix project
- Nix with flakes enabled

::: {.tip}
The fastest way to get started is the template:
`nix flake init -t github:Dauliac/nix-oci`: it scaffolds a ready-to-build flake for you.
:::

## Step 1: Add nix-oci to your flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-oci.url = "github:Dauliac/nix-oci";
  };

  outputs = inputs@{ flake-parts, nix-oci, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ nix-oci.modules.flake.nix-oci ];
      systems = [ "x86_64-linux" "aarch64-linux" ];

      oci.enabled = true;

      perSystem = { pkgs, ... }: {
        oci.containers.hello = {
          package = pkgs.hello;
        };
      };
    };
}
```

See [`oci.containers.<name>`](./reference/flake-parts-options.html) in the flake-parts option reference.

### How it works

Importing `nix-oci.modules.flake.nix-oci` registers the `oci.*` namespace on
the flake and inside every `perSystem`. Setting `oci.enabled = true` turns on
the flake outputs. Each entry in `oci.containers` becomes a package named
`oci-<name>` (the image derivation) plus a set of `apps.*` entries for loading
and pushing that image. The `hello` container above declares one option,
`package = pkgs.hello`, so nix-oci wraps that single binary as the container
entrypoint.

## Step 2: Build the image

```bash
# Build the OCI image. `result/bin/` contains the loader and push
# scripts: load-podman, load-docker, push, and sandbox.
nix build .#oci-hello
ls result/bin/

# Load it into Podman
nix run .#oci-load-podman-hello
# or load it into Docker
nix run .#oci-load-docker-hello
# or push to a registry
nix run .#oci-push-hello
```

### How it works

`nix build .#oci-hello` evaluates the nix2container image derivation without
touching a container daemon (Nix builds the layer tarballs directly from the
store). The `result/bin/` scripts come from the image passthru: `load-podman`
and `load-docker` stream layers into the local runtime without materialising an
intermediate archive, `push` uses skopeo to copy to a remote registry, and
`sandbox` runs a podman build inside a hermetic Nix sandbox to prove the image
runs.

## Step 3: Run it

```bash
podman run --rm localhost/hello:latest
# Hello, world!
```

### How it works

Once the image is loaded, podman treats it like any other locally cached image.
The `localhost/` prefix is the registry namespace podman assigns to images that
were loaded from a tarball or stream rather than pulled from a remote registry.
The `:latest` tag is the default nix-oci sets when no explicit `imageTag` is
provided.

## Step 4: Deploy on NixOS (optional)

Add the NixOS module to your system configuration:

```nix
# In your NixOS configuration
{ pkgs, nix-oci, ... }:
{
  imports = [ nix-oci.modules.nixos.nix-oci ];

  oci = {
    enable = true;
    backend = "podman";
    containers.hello = {
      package = pkgs.hello;
      autoStart = true;
    };
  };
}
```

See [`oci.containers.<name>`](./reference/nixos-options.html) in the NixOS option reference.

### How it works

The NixOS module reuses the same container definition as the flake-parts side
and wires it into systemd. Two units are generated per container:

- `oci-load-hello.service`: loads the image from the Nix store into Podman on
  boot (a one-shot unit that runs the passthru `load-podman` script).
- `podman-hello.service`: runs the container as a systemd service, so failures,
  restarts, and dependencies are managed the usual NixOS way.

Because the image is materialised in the Nix store, upgrades happen atomically
with the system generation: no `docker pull`, no drift between hosts.

## Step 5: Build from a NixOS service (optional)

Instead of packaging a binary, you can build a container directly from a
NixOS service definition:

```nix
perSystem = { ... }: {
  oci.containers.my-nginx = {
    nixosConfig = {
      mainService = "nginx";
      modules = [
        ({ ... }: {
          services.nginx = {
            enable = true;
            virtualHosts.localhost.locations."/".return = "200 'Hello!'";
          };
        })
      ];
    };
  };
};
```

### How it works

nix-oci evaluates the NixOS modules against a minimal, container-friendly base
profile (no kernel, no getty, no full systemd stack) and extracts three things:

1. The entrypoint (systemd unit or plain command) for `mainService`.
2. Users and groups declared by the service, materialised into `/etc/passwd`
   and `/etc/group`.
3. The transitive filesystem closure of the service (binaries, config,
   libraries), copied into the image root.

A single Nix expression drives everything, so you get NixOS ergonomics
(`services.nginx.enable = true`) without writing a Dockerfile. See
[`nixosConfig`](./reference/flake-parts-options.html) in the container module option reference.

::: {.tip}
The service adapter for nginx autoinjects a healthcheck endpoint, a stop
signal (`SIGQUIT`), and foreground mode; you get production-grade container
metadata automatically. Adapters exist for 10 services: nginx, httpd, caddy,
postgresql, redis, bind, dnsmasq, postfix, vsftpd, and php-fpm.
:::

## Step 6: Build on an external base image (optional)

Use `fromImage` to layer Nix packages on top of an existing OCI image
(for example from Docker Hub). Identity files (`/etc/passwd`, `/etc/group`)
get pre-extracted at lock time so evaluation stays pure (no IFD):

::: {.warning}
Commit the base image identity files to your repository.
Run the lock command first to extract them; see the
[`fromImage` reference](./reference/flake-parts-options.html) for details.
:::

```nix
perSystem = { pkgs, ... }: {
  oci.containers.my-app = {
    fromImage = {
      enabled = true;
      imageName = "docker.io/library/ubuntu";
      imageTag = "24.04";
    };
    package = pkgs.my-app;
  };
};
```

### How it works

`fromImage` layers your Nix-built content on top of an existing OCI image
instead of starting from an empty scratch base. At lock time, nix-oci extracts
identity files (`/etc/passwd`, `/etc/group`, `/etc/nsswitch.conf`, ...) from
the base image and commits them to the repository. That way the evaluation
stays pure (no import-from-derivation) and the resulting image is fully
reproducible even though the base is pulled from a remote registry. Your
package layer is appended on top, so consumers get a familiar userland (Ubuntu,
Debian, ...) with your app bolted on.

## Step 7: Add Home Manager configuration (optional)

Use `homeManager.modules` to configure dotfiles, shell, git, and editors
inside a container via Home Manager:

```nix
perSystem = { ... }: {
  oci.containers.dev-env = {
    package = pkgs.neovim;
    homeManager = {
      flake = inputs.home-manager;
      modules = [
        ({ ... }: {
          programs.git = {
            enable = true;
            userName = "dev";
          };
          programs.bash.enable = true;
        })
      ];
    };
  };
};
```

See [`homeManager`](./reference/flake-parts-options.html) in the container module option reference.

### How it works

nix-oci evaluates the Home Manager modules for the container's non-root user
and materialises the resulting `home.file`, dotfiles, and activation scripts
inside the image. The `flake` argument points at your Home Manager input so
nix-oci can reuse its module system; `modules` is the same list you would pass
to `home-manager.lib.homeManagerConfiguration`. This is convenient for dev
containers where you want your usual shell, git config, and editor prefs
without maintaining a separate dotfiles image.

## Step 8: Enable hardening (optional)

Enable seccomp, AppArmor, capability dropping, and more.
Seccomp profiles provide argument-level filtering
(namespace/socket/ioctl restrictions), `io_uring` blocking, and an audit
mode for profile discovery:

```nix
perSystem = { ... }: {
  oci.containers.my-nginx = {
    nixosConfig = {
      mainService = "nginx";
      modules = [({ ... }: { services.nginx.enable = true; })];
    };
    hardening.enable = true;
  };
};
```

See [Hardening](./security/hardening.html),
[Security defaults](./security/security-defaults.html), and
[`hardening.*`](./reference/flake-parts-options.html) in the option reference for details.

### How it works

`hardening.enable = true` flips on a bundle of image-level and runtime-level
defenses:

- A seccomp profile with argument-level filtering (namespace, socket, and
  ioctl restrictions), `io_uring` blocked, and an audit mode for iterative
  discovery of missing syscalls.
- Linux capabilities dropped to the minimum the declared service actually
  needs (auto-derived from the NixOS service adapter when one applies).
- `no-new-privileges`, a read-only rootfs where possible, and AppArmor
  attachment on hosts that support it.

Everything can be narrowed or widened via sub-options
(`hardening.seccomp.*`, `hardening.capabilities.*`, ...) so you never
have to disable the whole bundle to loosen one constraint.

## Step 9: Enable performance optimizations (optional)

Swap in alternative memory allocators or tune glibc at runtime:

```nix
perSystem = { ... }: {
  oci.containers.my-app = {
    package = pkgs.my-app;
    performance = {
      enable = true;
      allocator = "jemalloc";
      # `compression` accepts "gzip", "zstd", or "gzip:estargz"
      # (the last one produces an eStargz-compatible image for lazy pulling).
      compression = "zstd";
    };
  };
};
```

See [`performance.*`](./reference/flake-parts-options.html) in the option reference
and [Performance tuning](./architecture/performance.html) for details.

### How it works

`performance.allocator` swaps the default glibc allocator for `jemalloc`,
`mimalloc`, or `tcmalloc` via `LD_PRELOAD` inside the container entrypoint (the
allocator library is added to the image closure, no manual install). Allocator
choice tends to matter most for workloads with lots of small allocations or
high thread counts. `performance.compression` selects the image layer
compression: `gzip` (broadest compatibility), `zstd` (smaller, faster to
decompress), or `gzip:estargz` (still gzip-compatible but with an index so
compatible runtimes can lazy-pull individual files). Other `performance.*`
options tune glibc, CPU affinity, and I/O; nothing is enabled implicitly, so
you opt in per container.

## Step 10: Health-aware deployment (optional)

When a container has a healthcheck (autoderived from a service adapter or
set explicitly), the deploy modules wire `sdnotify` so dependent systemd
services wait until the container reports healthy (`READY=1`):

```nix
# NixOS deploy: healthcheck-aware by default
{ nix-oci, ... }:
{
  imports = [ nix-oci.modules.nixos.nix-oci ];

  oci = {
    enable = true;
    backend = "podman";
    containers.my-redis = {
      nixosConfig = {
        mainService = "redis";
        modules = [({ ... }: { services.redis.servers."".enable = true; })];
      };
      autoStart = true;
    };
  };
}
```

### How it works

The redis service adapter contributes a healthcheck (`redis-cli ping`), a stop
signal, and readiness metadata; nix-oci bakes that into the image as an OCI
`Healthcheck` and, on the deploy side, wires systemd notifications.
Concretely, the generated `podman-my-redis.service` uses `Type=notify` and
`--sdnotify=healthy`, so any service that depends on it (via
`Wants=`/`After=`) won't start until Redis passes its first
`redis-cli ping` healthcheck. No manual `ExecStartPost` polling, no
sleep-based hacks, no scripts to maintain.

::: {.tip}
Health-aware deployment works with all three deploy targets: NixOS
(`sdnotify`), Home Manager (Quadlet `Notify=healthy`), and
system-manager (direct podman flags). Docker-only deployments get the
healthcheck baked into the image but without systemd integration.
:::

## Step 11: Enable security scanning (optional)

nix-oci bundles CVE scanners, SBOM generation, image signing,
credentials leak detection, CIS compliance checks, and OCI config
policy validation. Enable what you need:

```nix
perSystem = { ... }: {
  oci.containers.my-app = {
    package = pkgs.my-app;

    # CVE scanning
    cve.trivy.enabled = true;

    # Image linting (CIS Docker Benchmarks)
    lint.dockle.enabled = true;

    # OCI config policy checking (Conftest / OPA Rego)
    policy.conftest.enabled = true;
  };
};
```

### How it works

Enabled tools run as part of the validation-gated build pipeline. The
gate composes every enabled step (CVE scan, lint, policy, SBOM, ...)
into a single derivation; if any step fails, `nix build .#oci-my-app`
fails.

```bash
# Runs every enabled scanner in the pipeline; the build fails on any
# scanner failure.
nix build .#oci-my-app

# Inspect the report artifacts.
ls result/report/
```

The per-tool scripts are also available under the built package's
`bin/` (for example `result/bin/cve-trivy`), and the full step
registry lives at
[`nix/modules/oci/pipeline/step-registrations.nix`](https://github.com/Dauliac/nix-oci/blob/main/nix/modules/oci/pipeline/step-registrations.nix).

Conftest ships built-in policies that check for root users, leaked
secrets in env vars, missing OCI labels, and missing entrypoints.
Override `policy.conftest.policyDir` with your own Rego files to add
organization-specific rules.

See [Supply-chain security](./security/index.html)
and [`cve.*`, `lint.*`, `policy.*`](./reference/flake-parts-options.html) in the option reference for the full set of security tools.

## Next steps

- [Container Modules API](./how-to/container-modules-api.html): deep dive into `nixosConfig.modules`
- [Deploy Modules](./how-to/deploy-modules.html): NixOS and Home Manager deployment
- [Hardening](./security/hardening.html): seccomp, AppArmor, capabilities
- [Options Reference](./reference/flake-parts-options.html): `performance.*` allocators, glibc tunables, compression
- [Automatic metadata](./architecture/automatic-metadata.html): healthchecks, stop signals, volumes
- [Automatic labeling](./architecture/automatic-labeling.html): OCI annotations, K8s PSS, security hints
- [Security scanning](./security/index.html): CVE, SBOM, signing, Conftest
- [Container probes](./security/container-probes.html): amicontained, CDK, DEEPCE, linPEAS
- [Options Reference](./reference/flake-parts-options.html): full option reference
