+++
title = "Getting Started"
description = "Build and deploy your first OCI container with nix-oci"
+++

# Getting Started

This tutorial walks you through building your first container image,
then deploying it on NixOS — all from Nix.

## Prerequisites

- A flake-based Nix project
- Nix with flakes enabled

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

This creates two systemd services:
- `oci-load-hello.service` — loads the image from the Nix store into Podman
- `podman-hello.service` — runs the container

## Step 5: Build from a NixOS service (optional)

Instead of packaging a binary, you can build a container directly from a
NixOS service definition:

```nix
perSystem = { ... }: {
  oci.containers.my-nginx = {
    nixosConfig = {
      enable = true;
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
filesystem, and builds a minimal OCI image — no Dockerfile needed.

## Next steps

- [Container Modules API](./how-to/container-modules-api.html) — deep dive into `nixosConfig.modules`
- [Deploy Modules](./how-to/deploy-modules.html) — NixOS and Home Manager deployment
- [Options Reference](./reference/flake-parts-toplevel.html) — full option reference
