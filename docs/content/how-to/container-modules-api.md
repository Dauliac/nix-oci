+++
title = "Build containers from NixOS services"
description = "How to turn NixOS service definitions into minimal OCI containers"
+++

# How to build containers from NixOS services

This guide shows you how to use `nixosConfig.modules` to build OCI containers
directly from NixOS service definitions, no Dockerfile needed.

## 1. Set up your flake

Start with a basic flake-parts flake with nix-oci:

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

      perSystem = { ... }: {
        oci.containers = {
          # containers go here
        };
      };
    };
}
```

## 2. Define a container from a NixOS service

Pick any NixOS service (e.g. nginx) and wrap it in `nixosConfig.modules`:

```nix
oci.containers.my-nginx = {
  nixosConfig = {
    mainService = "nginx";  # which systemd service to use as entrypoint
    modules = [
      ({ ... }: {
        services.nginx = {
          enable = true;
          virtualHosts.localhost = {
            locations."/".return = "200 'Hello from nix-oci!'";
          };
        };
      })
    ];
  };
};
```

That's it. nix-oci evaluates the NixOS modules, extracts the nginx binary
as the entrypoint, creates a non-root `nginx` user, and builds a minimal image.
See [`nixosConfig`](../reference/nix-oci-container-module-options.html) in the container module option reference.

## 3. Build and test

```bash
# Build the image
nix build .#oci-my-nginx

# Load it into Podman
nix run .#oci-copyToPodman-my-nginx

# Run it
podman run --rm -p 8080:80 localhost/my-nginx:latest

# Test
curl http://localhost:8080
```

## 4. Add extra packages to the container

Use `environment.systemPackages` inside the NixOS module, or `dependencies`
at the container level:

```nix
oci.containers.my-nginx = {
  # Container-level: always available in the image
  dependencies = [ pkgs.curl ];

  nixosConfig = {
    mainService = "nginx";
    modules = [
      ({ pkgs, ... }: {
        services.nginx.enable = true;
        # NixOS-level: also available in the image
        environment.systemPackages = [ pkgs.htop ];
      })
    ];
  };
};
```

## 5. Run as root or non-root

Containers run as a non-root user derived from the service name
(see [`isRoot`](../reference/flake-parts-options.html) option reference).
To run as root (required for some services like caddy that bind to port 80):

```nix
oci.containers.my-caddy = {
  isRoot = true;  # set at container level
  nixosConfig = {
    mainService = "caddy";
    modules = [({ ... }: {
      services.caddy = {
        enable = true;
        virtualHosts."localhost:8080".extraConfig = ''
          respond "Hello!"
        '';
      };
    })];
  };
};
```

## 6. Add container structure tests

Validate your container image with CST (see [`test.containerStructureTest`](../reference/flake-parts-options.html) in the option reference):

```nix
oci.containers.my-nginx = {
  nixosConfig = { /* ... */ };
  test.containerStructureTest = {
    enabled = true;
    configs = [ ./my-nginx-cst.yaml ];
  };
};
```

Create `my-nginx-cst.yaml`:

```yaml
schemaVersion: "2.0.0"
commandTests:
  - name: "nginx is present"
    command: "nginx"
    args: ["-v"]
    expectedOutput: ["nginx"]
```

Run the test:

```bash
nix run .#oci-container-structure-test-my-nginx
```

## 7. Push to a registry

See [`registry`](../reference/flake-parts-options.html) and [`push`](../reference/flake-parts-options.html) in the option reference.

```nix
oci.containers.my-nginx = {
  registry = "ghcr.io/myorg";
  tag = "v1.0";
  push = true;
  # ...
};
```

```bash
# Push the image
nix run .#oci-push-my-nginx-v1.0
```

## What NixOS services work?

Any NixOS service that defines a systemd unit with `ExecStart`. nix-oci
extracts the start command and uses it as the container entrypoint.
See [NixOS options search](https://search.nixos.org/options?query=services.)
for all available services.

For full option details, see [nix-oci container module options](../reference/nix-oci-container-module-options.html).

## Runnable example

A complete, testable flake for building from NixOS services is available at
[`examples/_how-to/build-from-nixos-service/`](https://github.com/Dauliac/nix-oci/tree/main/examples/_how-to/build-from-nixos-service).

```bash
cd examples/_how-to/build-from-nixos-service
nix flake show
```
