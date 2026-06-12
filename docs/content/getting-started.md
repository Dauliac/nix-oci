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

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nix-oci.modules.flake.nix-oci ];
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

## Step 2: Build the image

```bash
# Build the OCI image
nix build .#oci-hello

# Load it into Docker or Podman
nix run .#oci-copyToPodman-hello
# or
nix run .#oci-copyToDockerDaemon-hello
```

## Step 3: Run it

```bash
podman run --rm localhost/hello:latest
# Hello, world!
```

## Step 4: Deploy on NixOS (optional)

Add the NixOS module to your system configuration:

```nix
# In your NixOS configuration
{ inputs, pkgs, ... }:
{
  imports = [ inputs.nix-oci.modules.nixos.nix-oci ];

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

This creates two systemd services:
- `oci-load-hello.service`: loads the image from the Nix store into Podman
- `podman-hello.service`: runs the container

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

nix-oci evaluates the NixOS modules, extracts the entrypoint, users, and
filesystem, and builds a minimal OCI image; no Dockerfile needed.
See [`nixosConfig`](./reference/nix-oci-container-module-options.html) in the container module option reference.

::: {.tip}
The service adapter for nginx auto-injects a healthcheck endpoint, a stop
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

## Step 7: Add Home Manager configuration (optional)

Use `homeConfig.modules` to configure dotfiles, shell, git, and editors
inside a container via Home Manager:

```nix
perSystem = { ... }: {
  oci.containers.dev-env = {
    package = pkgs.neovim;
    homeConfig = {
      homeManagerFlake = inputs.home-manager;
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

See [`homeConfig`](./reference/nix-oci-container-module-options.html) in the container module option reference.

## Step 8: Enable hardening (optional)

Enable seccomp, Landlock, capability dropping, and more.
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

## Step 9: Enable performance optimizations (optional)

Swap in alternative memory allocators, tune glibc, or target a specific
CPU architecture:

```nix
perSystem = { ... }: {
  oci.containers.my-app = {
    package = pkgs.my-app;
    performance = {
      enable = true;
      allocator = "mimalloc";
      march = "x86-64-v3";
    };
  };
};
```

See [Performance integrations](./performance/performance-integrations.html)
and [`performance.*`](./reference/flake-parts-options.html) in the option reference for details.

## Step 10: Health-aware deployment (optional)

When a container has a healthcheck (auto-derived from a service adapter or
set explicitly), the deploy modules wire `sdnotify` so dependent systemd
services wait until the container reports healthy (`READY=1`):

```nix
# NixOS deploy -- healthcheck-aware by default
{ inputs, ... }:
{
  imports = [ inputs.nix-oci.modules.nixos.nix-oci ];

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

The generated `podman-my-redis.service` uses `Type=notify` and
`--sdnotify=healthy`, so any service that depends on it won't start
until Redis passes its first `redis-cli ping` healthcheck.

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

Run them as flake apps:

```bash
nix run .#oci-cve-trivy-my-app
nix run .#oci-lint-dockle-my-app
nix run .#oci-policy-conftest-my-app
```

Conftest ships built-in policies that check for root users, leaked
secrets in env vars, missing OCI labels, and missing entrypoints.
Override `policy.conftest.policyDir` with your own Rego files to add
organization-specific rules.

See [Supply-chain security](./security/index.html)
and [`cve.*`, `lint.*`, `policy.*`](./reference/flake-parts-options.html) in the option reference for the full set of security tools.

## Next steps

- [Container Modules API](./how-to/container-modules-api.html): deep dive into `nixosConfig.modules`
- [Deploy Modules](./how-to/deploy-modules.html): NixOS and Home Manager deployment
- [Hardening](./security/hardening.html): seccomp, Landlock, capabilities
- [Performance](./performance/performance-integrations.html): allocators, glibc tunables, march
- [Automatic metadata](./architecture/automatic-metadata.html): healthchecks, stop signals, volumes
- [Automatic labeling](./architecture/automatic-labeling.html): OCI annotations, K8s PSS, security hints
- [Security scanning](./security/index.html): CVE, SBOM, signing, Conftest
- [Container probes](./security/container-probes.html): amicontained, CDK, DEEPCE, linPEAS
- [Options Reference](./reference/flake-parts-options.html): full option reference
