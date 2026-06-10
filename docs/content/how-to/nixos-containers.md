+++
title = "Build and run with flake-parts"
description = "How to build OCI images and run common tasks using the flake-parts module"
+++

# How to build and run with flake-parts

This guide covers the day-to-day commands for building images, running
security scans, and managing containers with the flake-parts module.

## Build an image

```bash
# Build a specific container image
nix build .#oci-<container-name>

# Example
nix build .#oci-hello
```

The output is a nix2container image in the Nix store (not a tarball).

## Load into a container runtime

```bash
# Load into Podman
nix run .#oci-copyToPodman-<name>

# Load into Docker
nix run .#oci-copyToDockerDaemon-<name>

# Then run it
podman run --rm localhost/<name>:latest
```

## Push to a registry

Set `registry` and `push = true` on your container, then:

```bash
# Push a specific tag
nix run .#oci-push-<name>-<tag>

# Push all tags for a container
nix run .#oci-pushAllTags-<name>
```

## Run security scans

### CVE scanning

```bash
# Trivy
nix run .#oci-cve-trivy-<name>

# Grype
nix run .#oci-cve-grype-<name>

# Vulnix
nix run .#oci-cve-vulnix-<name>
```

Enable in your container config:

```nix
oci.cve.trivy.enabled = true;
# or
oci.cve.grype.enabled = true;
```

### SBOM generation

```bash
nix run .#oci-sbom-syft-<name>
```

### Credentials leak detection

```bash
nix run .#oci-credentials-leak-<name>
```

## Run tests

### Container Structure Tests

```bash
nix run .#oci-container-structure-test-<name>
```

### Dive (layer analysis)

```bash
nix run .#oci-dive-<name>
```

### dgoss

```bash
nix run .#oci-dgoss-<name>
```

## Build image flavours

Flavours let you create variant images that inherit from a parent container.
List options (dependencies, nixosConfig.modules) are additive; scalar options
(tag, isRoot) can be overridden.

```nix
oci.containers.my-app = {
  package = pkgs.myApp;

  # Debug flavour: adds tools on top of the production image
  flavours.debug = {
    dependencies = with pkgs; [ curl strace coreutils bash ];
  };

  # Slim flavour: strips TLS certs and DNS
  flavours.slim = {
    hardening.noTlsTrustStore = true;
    hardening.disableDns = true;
  };
};
```

```bash
# Build the debug variant
nix build .#oci-my-app-debug

# Build the slim variant
nix build .#oci-my-app-slim

# Shell into the debug image
podman run --rm -it localhost/my-app:latest-debug bash
```

## Build multi-arch images

Enable cross-compilation to build images for multiple architectures:

```nix
oci.containers.my-app = {
  package = pkgs.hello;
  multiArch = {
    enabled = true;
    systems = [ "x86_64-linux" "aarch64-linux" ];
  };
};
```

```bash
# Build the multi-arch manifest
nix build .#oci-multiarch-crossBuild
```

## Update pulled image manifest locks

If you use `fromImage` to base your containers on upstream images:

```bash
nix run .#oci-updatePulledManifestsLocks
```

## Run all checks

```bash
nix flake check
```

This runs all enabled tests (CST, dive, dgoss) as Nix checks.

For full option details, see [flake.parts options](../reference/flake-parts-options.html).

## Runnable example

A complete, testable flake for flake-parts basics is available at
[`examples/_how-to/flake-parts-basics/`](https://github.com/Dauliac/nix-oci/tree/main/examples/_how-to/flake-parts-basics).

```bash
cd examples/_how-to/flake-parts-basics
nix flake show
```
