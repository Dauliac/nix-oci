+++
title = "Explanation"
description = "Understanding how nix-oci works"
+++

# Explanation

Understand the concepts and design decisions behind nix-oci.

- [Design choices and best practices](./design-choices.md) — Overview of opinionated defaults: secure, minimal, reproducible, self-describing containers
- [Security defaults](./security-defaults.md) — Non-root by default, distroless by construction, built-in security tooling, bit-for-bit reproducibility
- [Automatic OCI labels](./automatic-labeling.md) — OCI standard annotations, build metadata, hardening hints, Kubernetes SecurityContext/PSS, network ports, Nix identity, nixpkgs security, Kyverno integration
- [Automatic metadata derivation](./automatic-metadata.md) — How healthchecks, stop signals, working directories, and volume declarations are auto-derived from NixOS service configuration
- [Archive-less container building](./archive-less-container-building.md) — How nix2container builds OCI images without intermediate archives, reducing store bloat and enabling streaming pushes
- [Optimized Layer Sharing](./optimize-layers.md) — How store-path popularity-based layering shares layers between containers
- [Container metadata wiring](./container-metadata-wiring.md) — How user options (ports, environment, user, entrypoint, labels, healthcheck, stopSignal, workingDir, volumes) and auto-generated labels flow into OCI image config, systemd services, and firewall rules
