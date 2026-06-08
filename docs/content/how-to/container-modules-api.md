+++
title = "Container Modules API"
description = "How nixosConfig.modules works for building containers from NixOS services"
+++

# Container Modules API

nix-oci lets you build OCI containers from NixOS service definitions using
`nixosConfig.modules`. This is the "dendritic" pattern: you write standard
NixOS configuration and nix-oci extracts what's needed for an OCI image.

## Basic Usage

```nix
perSystem = { ... }: {
  oci.containers.my-caddy = {
    nixosConfig = {
      enable = true;
      mainService = "caddy";
      modules = [
        ({ pkgs, ... }: {
          services.caddy = {
            enable = true;
            virtualHosts."localhost:8080".extraConfig = ''
              respond "Hello from nix-oci!"
            '';
          };
          environment.systemPackages = [ pkgs.curl ];
        })
      ];
    };
    isRoot = true;
  };
};
```

## How It Works

1. Your NixOS modules are evaluated in a minimal container context (`boot.isContainer = true`)
2. The `mainService` option tells nix-oci which systemd service to extract the entrypoint from
3. Users, groups, and shadow files are generated from `config.users.users`
4. `/etc` files and environment variables are extracted from the NixOS eval
5. Everything is assembled into a root filesystem and passed to `nix2container.buildImage`

## `nixosConfig` Options

| Option | Type | Description |
|--------|------|-------------|
| `enable` | `bool` | Enable NixOS module evaluation for this container |
| `mainService` | `string` | NixOS service name to derive the entrypoint from |
| `modules` | `list` | NixOS modules to evaluate inside the container |

## Container-Level Options

These are set alongside `nixosConfig`, not inside it:

| Option | Type | Description |
|--------|------|-------------|
| `isRoot` | `bool` | Run as root (default: `false`) |
| `dependencies` | `list of package` | Extra packages for the root filesystem |
| `configFiles` | `list of package` | Additional `/etc` file derivations |

## NixOS Service Compatibility

nix-oci includes **service adapters** for common NixOS services that need
special handling in containers:

| Service | Adapter | What It Does |
|---------|---------|-------------|
| nginx | `nginx.nix` | Sets daemon mode off for foreground execution |
| caddy | — | Works out of the box (runs in foreground by default) |
| bind | `bind.nix` | Adjusts for container networking |
| httpd | `httpd.nix` | Apache foreground mode |
| postfix | `postfix.nix` | Mail server container adjustments |
| vsftpd | `vsftpd.nix` | FTP server container adjustments |

If a service doesn't have an adapter, it may still work — nix-oci extracts
the `ExecStart` from the systemd unit and uses it as the entrypoint.

## `package` vs `mainService`

These are **mutually exclusive**:

- Use `mainService` when your container runs a NixOS service (nginx, redis, caddy...)
- Use `package` when your container runs a simple binary

```nix
# Using mainService (NixOS service)
oci.containers.web = {
  nixosConfig = {
    enable = true;
    mainService = "nginx";
    modules = [({ ... }: { services.nginx.enable = true; })];
  };
};

# Using package (simple binary)
oci.containers.hello = {
  package = pkgs.hello;
};
```

## User Derivation

When `isRoot = false` (default), nix-oci:

1. Derives the username from the service package name (e.g., `nginx`, `redis`)
2. Creates a non-root user with UID/GID 4000
3. Generates `/etc/passwd`, `/etc/shadow`, `/etc/group`
4. Creates the user's home directory

When `isRoot = true`, the container runs as root with standard root entries.

## Home Manager Inside Containers

nix-oci supports `homeConfig` for adding Home Manager configuration inside
a container's NixOS eval:

```nix
oci.containers.my-app = {
  nixosConfig = {
    enable = true;
    mainService = "my-app";
    modules = [ ... ];
  };
  homeConfig = {
    enable = true;
    homeManagerFlake = inputs.home-manager;
    modules = [
      ({ pkgs, ... }: {
        home.packages = [ pkgs.ripgrep ];
      })
    ];
  };
};
```
