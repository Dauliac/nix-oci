+++
title = "nix-oci"
description = "A flake-parts module for building OCI images with Nix"
+++

# nix-oci

A [flake-parts](https://flake.parts) module for building minimal, reproducible OCI container images using [nix2container](https://github.com/nlewo/nix2container).

## Features

- Declarative OCI image definitions via the Nix module system
- NixOS module evaluation inside containers (dendritic modules)
- Multi-arch cross-compilation support
- Security scanning (CVE, SBOM, credentials leak detection)
- Container structure tests (CST, dgoss, dive)
- Image signing with cosign
- Deploy modules for NixOS and Home Manager
- Debug image variants

## Quick Start

```nix
{
  inputs.nix-oci.url = "github:Dauliac/nix-oci";

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nix-oci.flakeModules.nix-oci ];

      oci.enabled = true;

      perSystem = { pkgs, ... }: {
        oci.containers.hello = {
          package = pkgs.hello;
          tag = "latest";
        };
      };
    };
}
```
