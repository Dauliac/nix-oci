# Shared: alternative memory allocator injection.
#
# glibc's ptmalloc2 creates 8*ncores arenas -- wasteful under cgroup limits.
# Injecting a modern allocator via LD_PRELOAD improves throughput and RSS.
#
# References:
#   - https://github.com/microsoft/mimalloc
#   - https://github.com/google/tcmalloc
{ lib, ... }:
{
  options.performance.allocator = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "mimalloc"
        "tcmalloc"
      ]
    );
    default = null;
    description = ''
      Alternative memory allocator injected via `LD_PRELOAD`.

      - `"mimalloc"` -- Microsoft's general-purpose allocator. Lowest RSS
        for small allocations, excellent for microservices.

      - `"tcmalloc"` -- Google's per-CPU-cache allocator. Best throughput
        for large allocation patterns and high-concurrency servers.

      - `null` -- use glibc's default ptmalloc2 (no injection).

      The allocator library is added as a container dependency and
      `LD_PRELOAD` is set in the OCI manifest `Env`.
    '';
    example = "mimalloc";
  };
}
