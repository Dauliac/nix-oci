# Shared: glibc malloc tunables for containerized workloads.
#
# glibc respects GLIBC_TUNABLES env var for runtime tuning of malloc,
# threading, and hardware capability detection. Key container issue:
# ptmalloc2 creates 8*ncores arenas based on host CPU count, not cgroup
# limits, inflating RSS by 20-40% in memory-constrained containers.
#
# References:
#   - https://www.gnu.org/software/libc/manual/html_node/Memory-Allocation-Tunables.html
#   - https://sourceware.org/glibc/manual/latest/html_node/Hardware-Capability-Tunables.html
{ lib, ... }:
{
  options.performance.glibcTunables = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = ''
      glibc tunables set via the `GLIBC_TUNABLES` environment variable.

      Keys are tunable names (e.g. `glibc.malloc.arena_max`), values
      are strings. Multiple tunables are colon-joined automatically.

      **Recommended for containers**:
      - `glibc.malloc.arena_max = "2"` — cap malloc arenas to reduce RSS
      - `glibc.malloc.mmap_threshold = "131072"` — reduce fragmentation
      - `glibc.malloc.tcache_count = "7"` — tune per-thread cache

      Only effective with glibc-based containers (not musl).
    '';
    example = {
      "glibc.malloc.arena_max" = "2";
    };
  };
}
