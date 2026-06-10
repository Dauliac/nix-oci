# Shared: alternative memory allocator injection.
#
# glibc's ptmalloc2 creates 8*ncores arenas -- wasteful under cgroup limits.
# Injecting a modern allocator via LD_PRELOAD improves throughput and RSS.
#
# References:
#   - https://github.com/microsoft/mimalloc
#   - https://github.com/google/tcmalloc
#   - https://github.com/jemalloc/jemalloc
#   - https://github.com/microsoft/snmalloc
{ lib, ... }:
{
  options.performance.allocator = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "mimalloc"
        "tcmalloc"
        "jemalloc"
        "snmalloc"
      ]
    );
    default = null;
    description = ''
      Alternative memory allocator injected via `LD_PRELOAD`.

      - `"mimalloc"` -- Microsoft's general-purpose allocator. Lowest RSS
        for small allocations, excellent for microservices. Works on musl.

      - `"tcmalloc"` -- Google's per-CPU-cache allocator. Best throughput
        for large allocation patterns and high-concurrency servers.
        Requires glibc (does not work on musl).

      - `"jemalloc"` -- Facebook's allocator used by Redis and Firefox.
        Best fragmentation resistance and P99 latency for long-running
        servers. Requires glibc (segfaults on musl).

        > **Warning**: jemalloc uses `MADV_FREE` by default, which inflates
        > cgroup RSS accounting. The module automatically sets
        > `muzzy_decay_ms:0` unless overridden via `allocatorConfig`.

      - `"snmalloc"` -- Microsoft Research lock-free allocator. Excellent
        for high cross-thread deallocation patterns (request/response
        servers where allocating thread differs from freeing thread).

      - `null` -- use glibc's default ptmalloc2 (no injection).

      The allocator library is added as a container dependency and
      `LD_PRELOAD` is set in the OCI manifest `Env`.
    '';
    example = "jemalloc";
  };
}
