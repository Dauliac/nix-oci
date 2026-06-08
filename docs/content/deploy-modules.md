+++
title = "Deploy Modules"
description = "NixOS and Home Manager modules for loading OCI images"
+++

# Deploy Modules

nix-oci provides NixOS and Home Manager modules that load built OCI images
into your container runtime (Docker or Podman) via systemd services.

## Usage (NixOS)

```nix
# In your NixOS configuration
{ inputs, ... }:
{
  imports = [ inputs.nix-oci.modules.nixos.nix-oci ];

  services.nix-oci = {
    enable = true;
    backend = "podman"; # or "docker"
    containers.myapp = {
      image = self.packages.x86_64-linux.oci-myapp;
      autoStart = true;
    };
  };
}
```

## Usage (Home Manager)

```nix
# In your Home Manager configuration
{ inputs, ... }:
{
  imports = [ inputs.nix-oci.modules.homeManager.nix-oci ];

  services.nix-oci = {
    enable = true;
    backend = "podman";
    containers.myapp = {
      image = self.packages.x86_64-linux.oci-myapp;
      autoStart = true;
    };
  };
}
```

## How It Works

For each container, a `nix-oci-load-<name>.service` oneshot unit is created.
It uses nix2container's built-in `copyToPodman` or `copyToDockerDaemon`
passthru scripts to load the image from the Nix store into the runtime.

When `autoStart` is true, an OCI container entry is also created
(`virtualisation.oci-containers` on NixOS, `services.podman` on Home Manager)
with the load service wired as a dependency.
