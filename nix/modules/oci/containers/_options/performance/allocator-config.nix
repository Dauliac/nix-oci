# Shared: per-allocator tuning configuration.
#
# Each allocator exposes runtime knobs via environment variables.
# These options generate the corresponding env vars in the OCI manifest.
#
# References:
#   - mimalloc: https://microsoft.github.io/mimalloc/environment.html
#   - tcmalloc: https://google.github.io/tcmalloc/tuning.html
#   - jemalloc: https://github.com/jemalloc/jemalloc/blob/dev/TUNING.md
{ lib, ... }:
{
  options.performance.allocatorConfig = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = ''
      Allocator-specific tuning parameters.

      Keys and values depend on the selected `performance.allocator`:

      **mimalloc** -- keys become `MIMALLOC_<KEY>` environment variables:
      - `PURGE_DELAY` = `"100"` -- ms before purging unused pages
      - `PURGE_DECOMMITS` = `"1"` -- use MADV_DONTNEED (cgroup-accurate RSS)
      - `ARENA_EAGER_COMMIT` = `"0"` -- lazy commit for memory-constrained
      - `ALLOW_LARGE_OS_PAGES` = `"1"` -- use 2MB huge pages

      **tcmalloc** -- keys become `TCMALLOC_<KEY>` environment variables:
      - `AGGRESSIVE_DECOMMIT` = `"true"` -- aggressively return memory to OS
      - `MAX_TOTAL_THREAD_CACHE_BYTES` = `"8388608"` -- 8MB thread cache cap
      - `RELEASE_RATE` = `"10.0"` -- OS memory return rate

      **jemalloc** -- keys are colon-joined into `MALLOC_CONF`:
      - `narenas` = `"2"` -- limit arenas (default: 4*ncpus)
      - `dirty_decay_ms` = `"5000"` -- dirty page purge timing
      - `muzzy_decay_ms` = `"0"` -- skip MADV_FREE (critical for cgroups)
      - `background_thread` = `"true"` -- offload purging
      - `retain` = `"false"` -- actually munmap under cgroup limits
      - `metadata_thp` = `"auto"` -- THP for jemalloc metadata

      **snmalloc** -- no runtime tunables (configured at compile time).

      When the selected allocator is `null`, this option is ignored.
    '';
    example = {
      "narenas" = "2";
      "dirty_decay_ms" = "5000";
      "muzzy_decay_ms" = "0";
      "background_thread" = "true";
    };
  };
}
