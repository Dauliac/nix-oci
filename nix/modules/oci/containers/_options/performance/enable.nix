# Shared: performance tuning master switch.
{ lib, ... }:
{
  options.performance.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable container performance tuning.

      When enabled, applies build-time optimizations (allocator injection,
      glibc tunables, CPU-targeted libraries) and generates runtime hints
      consumed by deploy modules.

      Three independent optimization axes are available:
      - **Allocator** -- replace glibc ptmalloc2 with mimalloc/tcmalloc via `LD_PRELOAD`
      - **glibc tunables** -- tune malloc arenas, tcache, mmap thresholds
      - **hwcaps** -- ship CPU-optimized library variants (glibc-hwcaps, per-arch)
    '';
  };
}
