+++
title = "NixOS module options"
+++

# NixOS Module Options

These options are available when you import `inputs.nix-oci.modules.nixos.nix-oci`
into your NixOS configuration.

See also:

- [NixOS manual](https://nixos.org/manual/nixos/stable/)
- [NixOS options search](https://search.nixos.org/options)
- [`virtualisation.oci-containers`](https://search.nixos.org/options?query=virtualisation.oci-containers) -- the NixOS option nix-oci wires into
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

<!-- OPTIONS:deploy -->
