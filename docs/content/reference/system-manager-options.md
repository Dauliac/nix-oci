+++
title = "system-manager module options"
+++

# system-manager Module Options

These options are available when you import `inputs.nix-oci.modules.systemManager.nix-oci`
into your [system-manager](https://system-manager.net) configuration.

See also:

- [system-manager documentation](https://system-manager.net)
- [system-manager on GitHub](https://github.com/numtide/system-manager)
- [nix-oci source: `nix/modules/deploy/nix-oci/system-manager/`](https://github.com/Dauliac/nix-oci/tree/main/nix/modules/deploy/nix-oci/system-manager)

```nix
{ inputs, pkgs, ... }:
{
  imports = [ inputs.nix-oci.modules.systemManager.nix-oci ];

  oci = {
    enable = true;
    backend = "podman";
    containers.my-app = {
      package = pkgs.hello;
      autoStart = true;
    };
  };
}
```

The deploy module creates systemd services to load and run containers,
similar to the NixOS module but targeting system-manager managed hosts.

<!-- OPTIONS:deploy -->
