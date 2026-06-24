+++
title = "Options: NixOS deploy"
+++

# Options: NixOS deploy

These options are available when you import `inputs.nix-oci.modules.nixos.nix-oci`
into your NixOS configuration.

See also:

- [NixOS manual](https://nixos.org/manual/nixos/stable/)
- [NixOS options search](https://search.nixos.org/options)
- [`virtualisation.oci-containers`](https://search.nixos.org/options?query=virtualisation.oci-containers): the NixOS option nix-oci wires into
- [nix-oci source: `nix/modules/deploy/nix-oci/nixos/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/deploy/nix-oci/nixos)

```nix
{ inputs, pkgs, ... }:
{
  imports = [ inputs.nix-oci.modules.nixos.nix-oci ];

  oci = {
    enable = true;
    backend = "podman";
    containers.my-app = {
      package = pkgs.hello;
      autoStart = true;
      ports = [ "8080:8080" ];
    };
  };
}
```

The deploy module creates systemd services (`oci-load-<name>.service`)
and wires into `virtualisation.oci-containers` when `autoStart` is true.

## SOCI snapshotter (`services.soci-snapshotter.*`)

The standalone soci-snapshotter module is automatically included when
you import `nix-oci`. It provides the `services.soci-snapshotter`
option namespace for configuring the SOCI v2 lazy-pulling daemon.

Auto-enabled when `oci.snapshotter.soci.enable = true` or when any
container has `performance.turbo.soci = true` with `backend = "docker"`.

See [Turbo push backend: standalone soci-snapshotter module](../performance/turbo-push-backend.html#standalone-soci-snapshotter-module) for usage and architecture.

<!-- OPTIONS:deploy -->
