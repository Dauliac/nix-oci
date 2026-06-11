# Shared: curated glibc tunables presets for common container workloads.
#
# Presets expand to concrete glibc.malloc.* tunables via mkDefault,
# so explicit glibcTunables always take precedence.
#
# References:
#   - https://www.gnu.org/software/libc/manual/html_node/Memory-Allocation-Tunables.html
{
  lib,
  pkgs,
  ...
}:
let
  example = "balanced";
in
{
  options.performance.glibcTunablesPreset = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "memory-constrained"
        "high-throughput"
        "balanced"
      ]
    );
    default = null;
    description = ''
      Curated glibc tunables preset for common container workloads.

      Presets set `glibcTunables` values via `mkDefault` -- explicit
      `glibcTunables` entries always take precedence.

      - `"memory-constrained"` -- for containers with <512MB memory limit.
        Aggressively reduces arena count and malloc overhead:
        `arena_max=2, trim_threshold=32768, top_pad=0,
         mmap_threshold=65536, tcache_count=3`

      - `"high-throughput"` -- for CPU-bound servers with ample memory.
        Maximizes allocation throughput:
        `arena_max=8, tcache_count=15, mxfast=256`

      - `"balanced"` -- safe defaults for general-purpose containers.
        Moderate arena count with sensible thresholds:
        `arena_max=4, trim_threshold=131072,
         mmap_threshold=131072, tcache_count=7`

      - `null` -- no preset (only explicit `glibcTunables` apply).

      Only effective with glibc-based containers (not musl).
    '';
    inherit example;
  };

  config._tests.performance-glibc-tunables-preset = {
    level = "eval";
    default = {
      package = pkgs.hello;
      performance.enable = true;
    };
    override = {
      package = pkgs.hello;
      performance.enable = true;
      performance.glibcTunablesPreset = example;
    };
  };
}
