+++
title = "Home Manager module options"
+++

# Home Manager Module Options

These options are available when you import `inputs.nix-oci.modules.homeManager.nix-oci`
into your Home Manager configuration.

```nix
{ inputs, pkgs, ... }:
{
  imports = [ inputs.nix-oci.modules.homeManager.nix-oci ];

  oci = {
    enable = true;
    backend = "podman";
    containers.my-app = {
      package = pkgs.hello;
    };
  };
}
```

The deploy module creates `systemd.user.services` and wires into
`services.podman` for rootless container management.

<!-- OPTIONS:deploy -->
