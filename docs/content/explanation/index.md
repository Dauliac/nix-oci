+++
title = "Explanation"
description = "Understanding how nix-oci works"
+++

# Explanation

Understand the concepts and design decisions behind nix-oci.

- [Just-in-time container building](./jit-container-building.md) — How nix2container builds OCI images without intermediate archives, reducing store bloat and enabling streaming pushes
- [Optimized Layer Sharing](./optimize-layers.md) — How store-path popularity-based layering shares layers between containers
