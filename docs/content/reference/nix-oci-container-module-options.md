+++
title = "nix-oci container module options"
+++

# nix-oci Container Module Options

**Build OCI containers from NixOS modules** — this is one of nix-oci's most powerful features.

Instead of writing Dockerfiles or manually assembling root filesystems, you write
standard [NixOS module configuration](https://nixos.org/manual/nixos/stable/#sec-writing-modules)
and nix-oci builds a minimal OCI image from it. Any NixOS service that can be
expressed as a module can become a container — nginx, caddy, redis, postgresql,
grafana, and [thousands more](https://search.nixos.org/options).

See also:

- [NixOS manual: Writing modules](https://nixos.org/manual/nixos/stable/#sec-writing-modules)
- [NixOS options search](https://search.nixos.org/options) — find any NixOS service option
- [NixOS packages search](https://search.nixos.org/packages) — find packages to include
- [NixOS manual: Container chapter](https://nixos.org/manual/nixos/stable/#ch-containers)
- [nix-oci source: `nix/modules/_nixos/oci/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/_nixos/oci)

## How it works

When you use `nixosConfig.modules`, nix-oci evaluates your NixOS modules in a
minimal container context (`boot.isContainer = true`). **You write standard
NixOS configuration** — nix-oci handles the rest:

```nix
oci.containers.my-nginx = {
  # Container-level options (set HERE, not inside modules)
  isRoot = false;
  dependencies = [ pkgs.curl ];

  nixosConfig = {
    enable = true;
    mainService = "nginx";
    modules = [
      # Inside modules: write standard NixOS configuration
      ({ pkgs, ... }: {
        services.nginx = {
          enable = true;
          virtualHosts.localhost.locations."/".return = "200 'Hello!'";
        };
        # Any NixOS option works: environment.systemPackages, users, etc.
        environment.systemPackages = [ pkgs.curl ];
      })
    ];
  };
};
```

nix-oci automatically:

1. Evaluates the NixOS modules in a minimal container context
2. Derives the **user** from the service package name (e.g. `nginx`)
3. Extracts the **entrypoint** from the systemd unit of `mainService`
4. Threads `isRoot`, `dependencies`, `configFiles` from the container level into the eval
5. Collects `/etc` files and environment variables from the NixOS eval
6. Generates `/etc/passwd`, `/etc/shadow`, `/etc/group`
7. Assembles the root filesystem and passes it to [nix2container](https://github.com/nlewo/nix2container)

## What NixOS features are supported

Since the container runs a real NixOS evaluation, you get access to the full
NixOS module system:

- **Any NixOS service** — `services.nginx`, `services.redis`, `services.caddy`,
  `services.postgresql`, `services.grafana`, etc.
  ([search all services](https://search.nixos.org/options?query=services.))
- **System packages** — `environment.systemPackages` for tools available in the container
- **Users and groups** — `users.users`, `users.groups` (nix-oci extracts `/etc/passwd` etc.)
- **Environment variables** — from systemd service units and NixOS config
- **`/etc` files** — all NixOS-managed `/etc` entries are included in the image
- **Networking config** — `networking.firewall`, DNS settings, etc.

## Service adapters

Some NixOS services need adjustments to run in a container (e.g. disabling
daemon/fork mode). nix-oci includes adapters for common services:

| Service | What the adapter does | NixOS option reference |
|---------|----------------------|----------------------|
| nginx   | Disables daemon mode for foreground execution | [`services.nginx`](https://search.nixos.org/options?query=services.nginx) |
| caddy   | Works out of the box (already foreground) | [`services.caddy`](https://search.nixos.org/options?query=services.caddy) |
| bind    | Adjusts for container networking | [`services.bind`](https://search.nixos.org/options?query=services.bind) |
| httpd   | Apache foreground mode | [`services.httpd`](https://search.nixos.org/options?query=services.httpd) |
| postfix | Mail server container adjustments | [`services.postfix`](https://search.nixos.org/options?query=services.postfix) |
| vsftpd  | FTP server container adjustments | [`services.vsftpd`](https://search.nixos.org/options?query=services.vsftpd) |

**Services without an adapter still work** — nix-oci extracts the `ExecStart`
from the systemd unit and uses it as the container entrypoint. If a service
forks to background, you may need to add a custom adapter or set
`mainService` to point to the correct unit.

## Examples

### Nginx with custom config

```nix
oci.containers.web = {
  nixosConfig = {
    enable = true;
    mainService = "nginx";
    modules = [({ pkgs, ... }: {
      services.nginx = {
        enable = true;
        virtualHosts.localhost = {
          locations."/".root = pkgs.writeTextDir "index.html" "<h1>Hello</h1>";
          locations."/api".proxyPass = "http://backend:3000";
        };
      };
    })];
  };
};
```

### Redis

```nix
oci.containers.cache = {
  nixosConfig = {
    enable = true;
    mainService = "redis";
    modules = [({ ... }: {
      services.redis.servers.default = {
        enable = true;
        port = 6379;
      };
    })];
  };
};
```

### Caddy with extra tools

```nix
oci.containers.proxy = {
  isRoot = true;
  nixosConfig = {
    enable = true;
    mainService = "caddy";
    modules = [({ pkgs, ... }: {
      services.caddy = {
        enable = true;
        virtualHosts."localhost:8080".extraConfig = ''
          respond "Hello from nix-oci!"
        '';
      };
      environment.systemPackages = [ pkgs.curl pkgs.jq ];
    })];
  };
};
```

## Internal options reference

These options are set **automatically** by nix-oci during the NixOS evaluation.
They are documented here for understanding and for advanced use cases
(e.g. writing custom NixOS modules that read `config.oci.container.user`
inside the container eval context).

<!-- OPTIONS:nixos-container -->
