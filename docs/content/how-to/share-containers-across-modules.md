+++
title = "Share containers between flake and deploy"
description = "How to define containers once and use them in both CI builds and NixOS/HM deployment"
+++

# How to share containers between flake-parts and NixOS/Home Manager

A common pattern: you build container images in CI using flake-parts, and
also deploy them on NixOS or Home Manager machines. You don't want to
define the container twice. This guide shows how to share container
definitions across both contexts.

## The problem

flake-parts and NixOS/HM are separate module evaluations. A container
defined in `perSystem.oci.containers` (build-time) isn't automatically
available in your NixOS config (deploy-time).

You need a way to:

1. Define the container **once**
2. Build it in CI via `nix build .#oci-<name>`
3. Deploy it on NixOS/HM via `oci.containers.<name>`

## Approach 1: shared Nix files (simple)

Create a shared file that both flake-parts and NixOS can import.

### Define the container in a shared file

Create `containers/my-app.nix`:

```nix
# containers/my-app.nix
# Shared container definition -- used by both flake-parts and NixOS deploy.
{ pkgs, ... }:
{
  package = pkgs.python3Minimal;
  dependencies = [ pkgs.bashInteractive pkgs.coreutils ];
  entrypoint = [
    "${pkgs.writeShellScript "serve" ''
      mkdir -p /tmp/www
      echo "Hello" > /tmp/www/index.html
      cd /tmp/www
      exec python3 -m http.server 8080
    ''}"
  ];
  ports = [ "8080:8080" ];
}
```

### Use it in flake-parts (CI builds)

```nix
# flake.nix
perSystem = { pkgs, ... }: {
  oci.containers.my-app = import ./containers/my-app.nix { inherit pkgs; };
};
```

Now CI can build and push:

```bash
nix build .#oci-my-app
nix run .#oci-push-my-app-latest
```

### Use it in NixOS (deploy)

```nix
# configuration.nix
{ nix-oci, pkgs, ... }:
{
  imports = [ nix-oci.modules.nixos.nix-oci ];

  oci = {
    enable = true;
    backend = "podman";
    containers.my-app = (import ./containers/my-app.nix { inherit pkgs; }) // {
      autoStart = true;  # deploy-specific: start the container
    };
  };
}
```

The container definition is shared. NixOS adds `autoStart` on top.

### Use it in Home Manager (deploy)

```nix
# home.nix
{ nix-oci, pkgs, ... }:
{
  imports = [ nix-oci.modules.homeManager.nix-oci ];

  oci = {
    enable = true;
    backend = "podman";
    containers.my-app = import ./containers/my-app.nix { inherit pkgs; };
  };
}
```

## Approach 2: import-tree and dendritic pattern (recommended for larger projects)

For projects with many containers, use [import-tree](https://github.com/denful/import-tree)
to auto-discover container definitions from a directory. This is the pattern
nix-oci itself uses internally.

### Directory structure

```
my-project/
├── flake.nix
├── containers/
│   ├── api.nix
│   ├── frontend.nix
│   └── worker.nix
├── deploy/
│   ├── nixos.nix
│   └── home-manager.nix
```

### Define containers as modules

Each file in `containers/` is a module that defines one container:

```nix
# containers/api.nix
{ pkgs, ... }:
{
  config.oci.containers.api = {
    package = pkgs.my-api;
    ports = [ "3000:3000" ];
    environment = {
      NODE_ENV = "production";
    };
  };
}
```

```nix
# containers/frontend.nix
{ pkgs, ... }:
{
  config.oci.containers.frontend = {
    nixosConfig = {
      enable = true;
      mainService = "nginx";
      modules = [({ ... }: {
        services.nginx = {
          enable = true;
          virtualHosts.localhost.locations."/".root = pkgs.my-frontend;
        };
      })];
    };
  };
}
```

### Auto-discover in flake-parts

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
    nix-oci.url = "github:Dauliac/nix-oci";
    import-tree.url = "github:denful/import-tree";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.nix-oci.modules.flake.nix-oci
        # Auto-discover all container definitions
        (inputs.import-tree ./containers)
      ];

      systems = [ "x86_64-linux" "aarch64-linux" ];
      oci.enabled = true;
    };
}
```

Now `nix build .#oci-api`, `nix build .#oci-frontend`, etc. all work
automatically. Adding a new file to `containers/` is enough.

### Share with NixOS deploy

In your NixOS config, import the same container files and add deploy config:

```nix
# deploy/nixos.nix
{ nix-oci, pkgs, ... }:
{
  imports = [ nix-oci.modules.nixos.nix-oci ];

  oci = {
    enable = true;
    backend = "podman";

    # Re-use the same container definitions
    containers.api = (import ../containers/api.nix { inherit pkgs; }).config.oci.containers.api // {
      autoStart = true;
    };

    containers.frontend = (import ../containers/frontend.nix { inherit pkgs; }).config.oci.containers.frontend // {
      autoStart = true;
      ports = [ "80:80" ];
    };
  };
}
```

### Simpler: extract just the attrs

If you want to avoid the `config.oci.containers.*` nesting, write
containers as plain attrsets instead of modules:

```nix
# containers/api.nix
{ pkgs }:
{
  package = pkgs.my-api;
  ports = [ "3000:3000" ];
  environment.NODE_ENV = "production";
}
```

Then in both flake-parts and NixOS:

```nix
# flake-parts
perSystem = { pkgs, ... }: {
  oci.containers.api = import ./containers/api.nix { inherit pkgs; };
};

# NixOS deploy
oci.containers.api = (import ./containers/api.nix { inherit pkgs; }) // {
  autoStart = true;
};
```

## Approach 3: pass the flake output directly

If your NixOS system is defined in the same flake, you can reference
the built image from flake-parts outputs:

```nix
# flake.nix
{
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ inputs.nix-oci.modules.flake.nix-oci ];
      systems = [ "x86_64-linux" ];
      oci.enabled = true;

      perSystem = { pkgs, ... }: {
        oci.containers.my-app = {
          package = pkgs.hello;
        };
      };

      flake.nixosConfigurations.my-server =
        inputs.nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };
          modules = [
            inputs.nix-oci.modules.nixos.nix-oci
            ({ pkgs, ... }: {
              oci = {
                enable = true;
                backend = "podman";
                containers.my-app = {
                  package = pkgs.hello;
                  autoStart = true;
                };
              };
            })
          ];
        };
    };
}
```

## Summary

| Approach | Best for | Complexity |
|----------|----------|-----------|
| Shared files | Small projects, 1-5 containers | Low |
| import-tree | Larger projects, monorepos | Medium |
| Flake output passthrough | Single-flake deployments | Low |

The key principle: **define container contents once, add deploy-specific
options (`autoStart`, extra `ports`) at the deploy site.**

For option details, see:
- [flake.parts options](../reference/flake-parts-options.html)
- [NixOS module options](../reference/nixos-options.html)
- [Home Manager module options](../reference/home-manager-options.html)

## Runnable example

A complete, testable flake for sharing containers is available at
[`examples/_how-to/share-containers/`](https://github.com/Dauliac/nix-oci/tree/main/examples/_how-to/share-containers).

```bash
cd examples/_how-to/share-containers
nix flake show
```
