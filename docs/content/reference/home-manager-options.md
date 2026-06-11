+++
title = "Home Manager module options"
+++

# Home Manager Module Options

These options are available when you import `inputs.nix-oci.modules.homeManager.nix-oci`
into your Home Manager configuration.

See also:

- [Home Manager manual](https://nix-community.github.io/home-manager/)
- [Home Manager options reference](https://nix-community.github.io/home-manager/options.xhtml)
- [`services.podman`](https://nix-community.github.io/home-manager/options.xhtml#opt-services.podman.containers): the HM option nix-oci wires into
- [nix-oci source: `nix/modules/deploy/nix-oci/home-manager/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/deploy/nix-oci/home-manager)

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
