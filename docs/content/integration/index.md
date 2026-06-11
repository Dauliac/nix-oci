+++
title = "Platform integration"
description = "NixOS and Home Manager integration, multi-architecture images, and hermetic sandbox testing"
+++

# Platform integration

nix-oci integrates with the broader Nix ecosystem: NixOS modules,
Home Manager, multi-architecture builds, and hermetic testing.

## Topics

- [NixOS & Home Manager integration](nixos-home-manager-integration.html)
  — how NixOS service definitions and Home Manager configs produce
  container images via a shared evaluation

- [Multi-architecture images](multi-arch-images.html)
  — cross-compilation, emulated builds, and OCI multi-arch manifests

- [Sandbox testing](sandbox.html)
  — Podman-in-Nix-sandbox for hermetic, reproducible container tests
