+++
title = "NixOS Container Modules"
description = "Dendritic NixOS modules for container configuration"
+++

# NixOS Container Modules

nix-oci evaluates NixOS modules inside a minimal container context to
derive users, entrypoints, environment variables, and root filesystems.

This is the "dendritic" module pattern: you write standard NixOS configuration
and nix-oci extracts the parts needed for an OCI image.

## Usage

```nix
oci.containers.caddy = {
  nixosConfig.modules = [
    ({ pkgs, ... }: {
      services.caddy.enable = true;
      oci.container = {
        mainService = "caddy";
        dependencies = [ pkgs.cacert ];
      };
    })
  ];
};
```

## Container Options

These options are available inside `nixosConfig.modules` under `oci.container.*`:

- `user` — Container user name (default: `"root"`)
- `isRoot` — Whether the container runs as root (default: `false`)
- `uid` / `gid` — UID/GID for non-root user (default: `4000`)
- `package` — Main package for the container (mutually exclusive with `mainService`)
- `mainService` — NixOS service to extract entrypoint from
- `entrypoint` — Container entrypoint (auto-derived from `mainService`)
- `dependencies` — Additional packages to include
- `configFiles` — Additional config file derivations

## How It Works

1. Your NixOS modules are evaluated in a minimal container context (`boot.isContainer = true`)
2. Users, groups, and shadow files are generated from `config.users.users`
3. `/etc` files and environment variables are extracted
4. The entrypoint is derived from the systemd service unit
5. Everything is assembled into a root filesystem layer
