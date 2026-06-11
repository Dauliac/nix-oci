+++
title = "Performance & optimization"
description = "Build-time and runtime performance optimizations: allocators, glibc tunables, march, layer strategies, and the turbo push backend"
+++

# Performance & optimization

nix-oci provides multiple layers of performance optimization, from
build-time layer strategies to runtime allocator selection and
hardware-specific tuning.

## Topics

- [Build optimizations](performance-integrations.html)
  — memory allocators (jemalloc, mimalloc, tcmalloc), glibc tunables,
  march/mtune, hardware capabilities (hwcaps)

- [Layer optimization](optimize-layers.html)
  — fine-grained vs coarse layer strategies, deduplication,
  dependency-based layer splitting

- [Turbo push backend](turbo-push-backend.html)
  — nix2container-turbo: cross-machine layer cache, SOCI v2 lazy pull,
  content-addressable chunk store
