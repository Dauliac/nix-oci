+++
title = "Performance tuning"
description = "How nix-oci optimises container runtime performance with memory allocators, glibc tunables, huge pages, startup optimisation, layer compression, and lazy-pull support"
+++

# Performance tuning

nix-oci exposes a set of per-container options under
[`performance.*`](../reference/flake-parts-options.html) that let you
trade generality for speed without leaving the Nix module system.
All tuning is **opt-in** — set `performance.enable = true` to activate
the subsystem, then pick the knobs you need.

```nix
oci.containers.my-app = {
  performance = {
    enable = true;
    allocator = "jemalloc";
    compression = "zstd";
  };
};
```

## What belongs here vs at the package level

nix-oci performance options are **runtime environment** and **image
transport** concerns — things that affect how the container *runs* or
how the image is *delivered*, not how the application binary is
*compiled*.

| Concern | Layer | Example |
|---|---|---|
| Allocator injection | Runtime (LD_PRELOAD) | `performance.allocator = "jemalloc"` |
| glibc tunables | Runtime (env var) | `performance.glibcTunablesPreset = "high-throughput"` |
| Huge pages | Runtime (env var) | `performance.hugePages.thpMode = "madvise"` |
| ld.so.cache | Image (pre-built file) | `performance.startup.ldSoCache = true` |
| Layer compression | Image transport | `performance.compression = "zstd"` |
| Push acceleration | Image transport | `performance.turbo.enable = true` |

**Compilation flags** like `-march`, LTO, and `-O3` change how the
binary is *built* — they belong at the **package level**, not in the
container module. The container is just a delivery vehicle (a filesystem
snapshot with JSON metadata). Whether you put an optimised binary in a
container, on a NixOS system, or run it directly does not matter — the
optimisation is in the derivation.

To optimise the compilation of your packages, use Nix-native mechanisms:

```nix
# nixpkgs hostPlatform — sets -march/-mtune globally for C/C++ packages
nixpkgs.hostPlatform = {
  system = "x86_64-linux";
  gcc.arch = "x86-64-v3";
  gcc.tune = "x86-64-v3";
};

# Rust — set CARGO_BUILD_RUSTFLAGS in your derivation
my-app = pkgs.buildRustPackage {
  CARGO_BUILD_RUSTFLAGS = "-C target-cpu=x86-64-v3 -C lto=thin";
  # ...
};

# Go — set GOAMD64 in your derivation
my-go-app = pkgs.buildGoModule {
  env.GOAMD64 = "v3";
  # ...
};
```

Then pass the optimised package to nix-oci. The container adds
runtime-level tuning on top:

```nix
oci.containers.my-app = {
  package = my-app; # already compiled with -march=x86-64-v3
  performance = {
    enable = true;
    allocator = "jemalloc"; # runtime injection, binary unchanged
  };
};
```

## Memory allocators

The default glibc `malloc` is a solid general-purpose allocator, but
specialised allocators can yield significant wins for specific workload
profiles. nix-oci injects them via `LD_PRELOAD` at runtime — the
application binary is unchanged.

| Allocator | Best for | Injected via |
|---|---|---|
| **mimalloc** | Small, short-lived allocations | `LD_PRELOAD=libmimalloc.so` |
| **jemalloc** | Fragmentation-resistant, long-running services | `LD_PRELOAD=libjemalloc.so` |
| **tcmalloc** | High-concurrency, thread-heavy workloads | `LD_PRELOAD=libtcmalloc.so` |
| **snmalloc** | Cross-thread deallocation patterns | `LD_PRELOAD=libsnmallocshim.so` |

Set `performance.allocator` to one of these values. The corresponding
package is added to the image and the `LD_PRELOAD` environment variable
is generated automatically.

### Which languages benefit?

`LD_PRELOAD` allocators work for any language whose runtime calls
`malloc` through glibc:

| Language | Benefit | Notes |
|---|---|---|
| C/C++ | Full | All allocations go through malloc |
| Node.js | Full | V8 uses malloc for heap management |
| Rust | Full | Default allocator uses libc malloc |
| Java/JVM | Partial | Only JNI/native code; JVM manages its own heap |
| Go | None | Go has its own allocator, bypasses glibc |

### Allocator configuration

Per-allocator tuning knobs are exposed via `performance.allocatorConfig`
(an attribute set of strings). The keys are turned into environment
variables following each allocator's convention:

```nix
performance = {
  allocator = "jemalloc";
  allocatorConfig = {
    # jemalloc uses MALLOC_CONF (comma-separated key:value)
    narenas = "4";
    background_thread = "true";
  };
};
```

| Allocator | Env var pattern |
|---|---|
| mimalloc | `MIMALLOC_<KEY>` |
| tcmalloc | `TCMALLOC_<KEY>` |
| jemalloc | `MALLOC_CONF` (comma-separated) |
| snmalloc | No runtime tunables |

> **Note:** snmalloc has no runtime configuration. A warning is
> emitted if you set `allocatorConfig` with snmalloc.

## glibc tunables

For workloads that stay on glibc's allocator (or want to tune glibc
itself alongside an injected allocator), nix-oci exposes two options:

### Presets

`performance.glibcTunablesPreset` selects a curated set of
`GLIBC_TUNABLES` values:

| Preset | Arena max | Trim threshold | mmap threshold | tcache count | mxfast |
|---|---|---|---|---|---|
| `"memory-constrained"` | 2 | 32768 | 65536 | 3 | — |
| `"high-throughput"` | 8 | — | — | 15 | 256 |
| `"balanced"` | 4 | 131072 | 131072 | 7 | — |

### Explicit tunables

`performance.glibcTunables` is an attribute set that maps directly to
`GLIBC_TUNABLES` entries (colon-joined). Explicit values override
any preset.

```nix
performance = {
  glibcTunablesPreset = "high-throughput";
  glibcTunables = {
    "glibc.malloc.arena_max" = "16"; # override preset's 8
  };
};
```

## Huge pages

`performance.hugePages` controls transparent huge page (THP) and
glibc hugetlb behaviour:

| Option | Values | Effect |
|---|---|---|
| `hugePages.thpMode` | `"madvise"`, `"always"` | Sets `GLIBC_TUNABLES` for THP mode |
| `hugePages.glibcHugetlb` | `0`, `1`, `2` | Configures glibc's hugetlb support level |

## Hardware capabilities (hwcaps)

`performance.hwcaps` enables glibc's `hwcaps` mechanism to load
CPU-optimised library variants at runtime:

```nix
performance.hwcaps = {
  enable = true;
  levels = [ "x86-64-v3" ];
  libraries = [ pkgs.openssl ]; # provide v3-optimised .so
};
```

The container ships multiple library variants and glibc picks the
best match for the host CPU at load time, so the same image works
on both older and newer hardware. This is a **container-level concern**
because it decides *what goes into the image* (multiple .so variants),
even though the optimised libraries themselves are built at the package
level.

## Startup optimisation

`performance.startup` reduces cold-start latency:

| Option | Default | Effect |
|---|---|---|
| `startup.ldSoCache` | `false` | Pre-builds `/etc/ld.so.cache` so the dynamic linker skips directory scanning |
| `startup.stackSize` | `null` | Sets thread stack size (e.g. `"2M"`) via the `STACK_SIZE` env var |

## Layer compression

`performance.compression` controls how OCI image layers are compressed:

| Value | Trade-off |
|---|---|
| `"gzip"` (default) | Maximum compatibility with all registries and runtimes |
| `"zstd"` | 3-5x faster decompression, smaller layers; requires registry support (OCI 1.1+) |
| `"gzip:estargz"` | eStargz format enabling lazy pulling on compatible runtimes |

```nix
performance.compression = "zstd";
```

## Turbo push backend

The `performance.turbo.*` options enable
[nix2container-turbo](../reference/flake-parts-options.html), a patched
skopeo backend that accelerates image pushes:

| Option | Default | Effect |
|---|---|---|
| `turbo.enable` | `false` | Use turbo skopeo for pushes |
| `turbo.layerCache` | `true` | Cross-machine layer caching via OCI Referrers API (maps Nix store paths to compressed layers) |
| `turbo.soci` | `false` | Generate SOCI v2 indexes during push for lazy pulling on AWS ECS/Fargate |
| `turbo.sociSpanSize` | `4194304` (4 MiB) | zTOC checkpoint granularity (1 MiB = fine, 8 MiB = coarse) |

```nix
performance.turbo = {
  enable = true;
  soci = true;
  sociSpanSize = 1048576; # 1 MiB for fine-grained lazy pull
};
```

## Auto-generated labels

When performance tuning is enabled, nix-oci generates OCI labels under
the `io.github.dauliac.nix-oci.performance` namespace so the image
self-documents its optimisation profile:

```
io.github.dauliac.nix-oci.performance.enabled = "true"
io.github.dauliac.nix-oci.performance.allocator = "jemalloc"
io.github.dauliac.nix-oci.performance.glibc-tunables-preset = "high-throughput"
```

See [Automatic labeling](automatic-labeling.html) for the full label
taxonomy.

## Full example

```nix
oci.containers.my-api = {
  package = pkgs.my-api;

  performance = {
    enable = true;

    # Runtime memory (LD_PRELOAD, env vars — binary unchanged)
    allocator = "jemalloc";
    allocatorConfig.background_thread = "true";
    glibcTunablesPreset = "high-throughput";

    # Image transport
    compression = "zstd";

    # Startup
    startup.ldSoCache = true;

    # Push
    turbo = {
      enable = true;
      soci = true;
    };
  };
};
```

## Further reading

- [Design choices](design-choices.html): overall nix-oci philosophy
- [Automatic labeling](automatic-labeling.html): how labels encode the performance profile
- [Archive-less container building](archive-less-container-building.html): how nix2container avoids tar overhead
- [Security defaults](../security/security-defaults.html): how security and performance defaults interact
- [`performance.*` option reference](../reference/flake-parts-options.html): full option specification
- [NixOS Wiki: Build flags](https://wiki.nixos.org/wiki/Build_flags): how to set `-march` and LTO at the package level
