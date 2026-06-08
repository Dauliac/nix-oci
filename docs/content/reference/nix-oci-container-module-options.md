+++
title = "nix-oci container module options"
+++

# nix-oci Container Module Options

These are the **internal** options used by nix-oci when evaluating NixOS modules
inside a container build. They live under `oci.container.*` in the NixOS eval context.

## How it works

When you use `nixosConfig.modules`, nix-oci evaluates your NixOS modules in a
minimal container context. **You write standard NixOS configuration** — nix-oci
handles the rest:

```nix
oci.containers.my-nginx = {
  # Container-level options (set HERE, not inside modules)
  isRoot = false;
  dependencies = [ pkgs.curl ];

  nixosConfig = {
    enable = true;
    mainService = "nginx";
    modules = [
      # Inside modules: standard NixOS config only
      ({ ... }: {
        services.nginx = {
          enable = true;
          virtualHosts.localhost.locations."/".return = "200 'Hello!'";
        };
        environment.systemPackages = [ pkgs.curl ];
      })
    ];
  };
};
```

nix-oci automatically:

1. Derives the **user** from the service package name (e.g. `nginx`)
2. Threads `isRoot`, `dependencies`, `configFiles` from the container level into the eval
3. Extracts the **entrypoint** from the systemd unit of `mainService`
4. Generates `/etc/passwd`, `/etc/shadow`, `/etc/group`
5. Assembles the root filesystem

## NixOS compatibility

The container evaluation runs with `boot.isContainer = true` and includes
service adapters for common NixOS services:

| Service | What the adapter does |
|---------|----------------------|
| nginx   | Disables daemon mode for foreground execution |
| caddy   | Works out of the box (already foreground) |
| bind    | Adjusts for container networking |
| httpd   | Apache foreground mode |
| postfix | Mail server container adjustments |
| vsftpd  | FTP server container adjustments |

Most NixOS services work without an adapter — nix-oci extracts the `ExecStart`
from the systemd unit and uses it as the container entrypoint.

## Internal options reference

These options are set **automatically** by nix-oci. They are documented here for
understanding and advanced use cases (e.g. custom NixOS modules that need to
read `oci.container.user`).

<!-- OPTIONS:nixos-container -->
