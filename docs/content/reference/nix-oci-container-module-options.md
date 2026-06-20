+++
title = "nix-oci container module options"
+++

# nix-oci Container Module Options

**Build OCI containers from NixOS modules**: this is one of nix-oci's most powerful features.

Instead of writing Dockerfiles or manually assembling root filesystems, you write
standard [NixOS module configuration](https://nixos.org/manual/nixos/stable/#sec-writing-modules)
and nix-oci builds a minimal OCI image from it. You can turn any NixOS service
module into a container: nginx, caddy, redis, postgresql,
grafana, and [thousands more](https://search.nixos.org/options).

See also:

- [NixOS manual: Writing modules](https://nixos.org/manual/nixos/stable/#sec-writing-modules)
- [NixOS options search](https://search.nixos.org/options): find any NixOS service option
- [NixOS packages search](https://search.nixos.org/packages): find packages to include
- [NixOS manual: Container chapter](https://nixos.org/manual/nixos/stable/#ch-containers)
- [nix-oci source: `nix/modules/_nixos-oci/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/_nixos-oci)

## How it works

When you use `nixosConfig.modules`, nix-oci evaluates your NixOS modules in a
minimal container context (`boot.isContainer = true`). **You write standard
NixOS configuration**; nix-oci handles the rest:

```nix
oci.containers.my-nginx = {
  # Container-level options
  isRoot = false;
  dependencies = [ pkgs.curl ];
  mainService = "nginx";

  nixosConfig.modules = [
    # Inside modules: write standard NixOS configuration
    ({ pkgs, ... }: {
      services.nginx = {
        enable = true;
        virtualHosts.localhost.locations."/".return = "200 'Hello!'";
      };
    })
  ];
};
```

nix-oci automatically:

1. Evaluates the NixOS modules in a minimal container context
2. Derives the **user** from the service package name (e.g. `nginx`)
3. Extracts the **entrypoint** from the systemd unit of `mainService`
4. Routes container options via NixOS-native mechanisms (`environment.variables`,
   `extraPackages`, `generatedLabels`, `includedEtcFiles`)
5. Collects `/etc` files (only those registered via `includedEtcFiles`) and environment variables
6. Generates `/etc/passwd`, `/etc/shadow`, `/etc/group` from `users.users`
7. Assembles the root filesystem via `mkOCIImage` and passes it to [nix2container](https://github.com/nlewo/nix2container)

## Supported NixOS features

Since the container runs a real NixOS evaluation, you get access to the full
NixOS module system:

- **Any NixOS service**: `services.nginx`, `services.redis`, `services.caddy`,
  `services.postgresql`, `services.grafana`, etc.
  ([search all services](https://search.nixos.org/options?query=services.))
- **Users and groups**: `users.users`, `users.groups` (nix-oci extracts `/etc/passwd` etc.)
- **Environment variables**: via NixOS `environment.variables` (used by performance, GPU, and other modules)
- **`/etc` files**: nix-oci includes registered `/etc` entries (nsswitch.conf, SSL certs, nix.conf)
- **Module composition**: `imports`, `mkDefault`, `mkForce`, `mkIf` — full NixOS module system

> **Note**: Some NixOS features are intentionally restricted in containers:
> `environment.systemPackages` is cleared (use `dependencies` instead),
> `networking.firewall` is forbidden (no kernel iptables access), and
> `system.activationScripts` is blocked (no init system).

## Service adapters

Some NixOS services need adjustments to run in a container (e.g. disabling
daemon/fork mode). nix-oci includes adapters for common services:

| Service | What the adapter does | NixOS option reference |
|---------|----------------------|----------------------|
| nginx   | Foreground mode, auto healthcheck, SIGQUIT | [`services.nginx`](https://search.nixos.org/options?query=services.nginx) |
| caddy   | Works out of the box, admin API healthcheck | [`services.caddy`](https://search.nixos.org/options?query=services.caddy) |
| postgresql | pg_isready healthcheck, SIGINT shutdown | [`services.postgresql`](https://search.nixos.org/options?query=services.postgresql) |
| redis   | redis-cli ping healthcheck | [`services.redis`](https://search.nixos.org/options?query=services.redis) |
| bind    | dig healthcheck, foreground mode | [`services.bind`](https://search.nixos.org/options?query=services.bind) |
| dnsmasq | dig healthcheck | [`services.dnsmasq`](https://search.nixos.org/options?query=services.dnsmasq) |
| httpd   | Apache foreground mode | [`services.httpd`](https://search.nixos.org/options?query=services.httpd) |
| phpfpm  | FastCGI healthcheck | [`services.phpfpm`](https://search.nixos.org/options?query=services.phpfpm) |
| postfix | start-fg mode | [`services.postfix`](https://search.nixos.org/options?query=services.postfix) |
| vsftpd  | FTP probe | [`services.vsftpd`](https://search.nixos.org/options?query=services.vsftpd) |

**Services without an adapter still work**: nix-oci extracts the `ExecStart`
from the systemd unit and uses it as the container entrypoint.

## Examples

### Nginx with custom config

```nix
oci.containers.web = {
  mainService = "nginx";
  nixosConfig.modules = [({ pkgs, ... }: {
    services.nginx = {
      enable = true;
      virtualHosts.localhost = {
        locations."/".root = pkgs.writeTextDir "index.html" "<h1>Hello</h1>";
        locations."/api".proxyPass = "http://backend:3000";
      };
    };
  })];
};
```

### Redis

```nix
oci.containers.cache = {
  mainService = "redis";
  nixosConfig.modules = [({ ... }: {
    services.redis.servers.default = {
      enable = true;
      port = 6379;
    };
  })];
};
```

### Caddy with extra tools

```nix
oci.containers.proxy = {
  isRoot = true;
  mainService = "caddy";
  dependencies = [ pkgs.curl pkgs.jq ];
  nixosConfig.modules = [({ ... }: {
    services.caddy = {
      enable = true;
      virtualHosts."localhost:8080".extraConfig = ''
        respond "Hello from nix-oci!"
      '';
    };
  })];
};
```

## Home-manager integration

Containers can bake [home-manager](https://nix-community.github.io/home-manager/)
dotfiles into the image with `homeManager`. When enabled, nix-oci injects
container-friendly defaults (bash, [starship](https://starship.rs/) prompt)
that are especially useful with the [container sandbox](../integration/sandbox.md).

```nix
oci.containers.my-app = {
  isRoot = false;
  package = pkgs.curl;

  homeManager = {
    flake = inputs.home-manager;
    modules = [
      ({ ... }: {
        programs.git = {
          enable = true;
          userName = "dev";
          userEmail = "dev@container";
        };
      })
    ];
  };
};
```

See also:

- [Container sandbox](../integration/sandbox.md): rootless shell into the container filesystem
- [home-manager options reference](https://nix-community.github.io/home-manager/options.xhtml)
- [starship configuration](https://starship.rs/config/)
- [NixOS and home-manager integration](../integration/nixos-home-manager-integration.md)

## Internal options reference

nix-oci sets these options **automatically** during the NixOS evaluation.
This section documents them for understanding and for advanced use cases
(e.g. writing custom NixOS modules that read `config.oci.container.user`
inside the container eval context).

<!-- OPTIONS:nixos-container -->
