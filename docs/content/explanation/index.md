+++
title = "Explanation"
description = "Understanding how nix-oci works"
+++

# Explanation

Understand the concepts and design decisions behind nix-oci.

- [Archive-less container building](./archive-less-container-building.md) — How nix2container builds OCI images without intermediate archives, reducing store bloat and enabling streaming pushes
- [Optimized Layer Sharing](./optimize-layers.md) — How store-path popularity-based layering shares layers between containers
- [Container metadata wiring](./container-metadata-wiring.md) — How user options (ports, environment, user, entrypoint, labels, healthcheck, stopSignal, workingDir, volumes) flow into OCI image config, systemd services, and firewall rules
- [Design choices and best practices](./design-choices.md) — Why nix-oci defaults to non-root, distroless, FHS-structured containers with automatic naming, and how those choices keep images secure, small, and predictable
