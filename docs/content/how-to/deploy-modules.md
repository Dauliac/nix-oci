+++
title = "Deploy containers on NixOS"
description = "How to deploy and run OCI containers on a NixOS system using nix-oci"
+++

# How to deploy containers on NixOS

This guide walks you through setting up a NixOS system that builds, loads,
and runs OCI containers using nix-oci.

## 1. Add nix-oci to your flake

In your system flake (`flake.nix`), add nix-oci as an input:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-oci.url = "github:Dauliac/nix-oci";
  };

  outputs = { nixpkgs, nix-oci, ... }: {
    nixosConfigurations.my-server = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit nix-oci; };
      modules = [
        ./configuration.nix
      ];
    };
  };
}
```

## 2. Import the nix-oci NixOS module

In your `configuration.nix`, import the module and define containers:

```nix
{ nix-oci, pkgs, ... }:
{
  imports = [ nix-oci.modules.nixos.nix-oci ];

  oci = {
    enable = true;
    backend = "podman";  # or "docker"

    containers.my-webserver = {
      package = pkgs.python3Minimal;
      dependencies = [ pkgs.bashInteractive pkgs.coreutils ];
      entrypoint = [
        "${pkgs.writeShellScript "serve" ''
          mkdir -p /tmp/www
          echo "Hello from nix-oci" > /tmp/www/index.html
          cd /tmp/www
          exec python3 -m http.server 8080
        ''}"
      ];
      autoStart = true;
      ports = [ "8080:8080" ];
    };
  };
}
```

## 3. Build and deploy

```bash
# Build the NixOS system (includes the container)
sudo nixos-rebuild switch --flake .#my-server
```

nix-oci creates two systemd services:

- `oci-load-my-webserver.service` — loads the image from the Nix store into Podman
- `podman-my-webserver.service` — runs the container (only when `autoStart = true`)

## 4. Verify

```bash
# Check the services
systemctl status oci-load-my-webserver
systemctl status podman-my-webserver

# Check the container is running
podman ps

# Test the service
curl http://localhost:8080
```

## 5. Use multiple containers

You can define as many containers as you need:

```nix
oci = {
  enable = true;
  backend = "podman";

  containers.frontend = {
    package = pkgs.nginx;
    autoStart = true;
    ports = [ "80:80" ];
  };

  containers.api = {
    package = pkgs.my-api;
    autoStart = true;
    ports = [ "3000:3000" ];
    environment = {
      DATABASE_URL = "postgresql://localhost/mydb";
    };
  };
};
```

## Using Docker instead of Podman

Change the backend:

```nix
oci = {
  enable = true;
  backend = "docker";
  # ...
};
```

Make sure Docker is enabled on the system:

```nix
virtualisation.docker.enable = true;
```

For full option reference, see [NixOS module options](../reference/nixos-options.html).

## Runnable example

A complete, testable flake for deploying on NixOS is available at
[`examples/_how-to/deploy-nixos/`](https://github.com/Dauliac/nix-oci/tree/main/examples/_how-to/deploy-nixos).

```bash
cd examples/_how-to/deploy-nixos
nix flake show
```
