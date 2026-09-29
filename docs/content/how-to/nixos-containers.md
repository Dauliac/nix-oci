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
nix run .#oci-load-podman-<name>

# Load into Docker
nix run .#oci-load-docker-<name>

# Then run it
podman run --rm localhost/<name>:latest
```

## Push to a registry

The push app runs the full validation-gated pipeline (pre-push CVE scans →
push → post-push signing) before publishing:

```bash
nix run .#oci-push-<name>
```

## Run security scans

Scanners run as part of the validation-gated build pipeline. Enabling a
scanner on a container makes it a prerequisite of `nix build .#oci-<name>`:
if the scanner fails, the build fails. Reports land under
`$NIX_OCI_REPORT_DIR` (defaults to `result/report/`). See
[`nix/modules/oci/pipeline/step-registrations.nix`](https://github.com/Dauliac/nix-oci/blob/main/nix/modules/oci/pipeline/step-registrations.nix)
for the full step registry.

### CVE, SBOM, credentials, tests

Enable in your container config (see [`cve.*`](../reference/flake-parts-options.html),
[`sbom.*`](../reference/flake-parts-options.html), [`credentialsLeak.*`](../reference/flake-parts-options.html),
and [`test.*`](../reference/flake-parts-options.html) in the option reference):

```nix
oci.containers.<name> = {
  cve.trivy.enabled = true;                  # or grype, vulnix
  sbom.syft.enabled = true;
  credentialsLeak.trivy.enabled = true;
  test.containerStructureTest.enabled = true;  # or dive, dgoss
};
```

Then build; the gate runs every enabled step:

```bash
nix build .#oci-<name>
ls result/report/
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

See [`flavours`](../reference/flake-parts-options.html) in the flake-parts option reference.

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
  multiArch.systems = [ "x86_64-linux" "aarch64-linux" ];
};
```

`multiArch.enabled` is computed automatically from `multiArch.systems`
(non-empty list turns it on); it's read-only and can't be set directly.
See [`multiArch`](../reference/flake-parts-options.html) in the flake-parts
option reference.

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

For full option details, see [Options: flake-parts](../reference/flake-parts-options.html).

## Runnable example

A complete, testable flake for flake-parts basics is available at
[`examples/_how-to/flake-parts-basics/`](https://github.com/Dauliac/nix-oci/tree/main/examples/_how-to/flake-parts-basics).

```bash
cd examples/_how-to/flake-parts-basics
nix flake show
```
