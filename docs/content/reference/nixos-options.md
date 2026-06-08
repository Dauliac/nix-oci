+++
title = "NixOS module options"
+++

# NixOS Module Options

These options are available when you import `inputs.nix-oci.modules.nixos.nix-oci`
into your NixOS configuration.

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
