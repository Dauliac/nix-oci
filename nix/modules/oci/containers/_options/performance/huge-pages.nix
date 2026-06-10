# Shared: transparent huge page and explicit huge page configuration.
#
# THP can reduce TLB misses by an order of magnitude and decrease
# page walk latency by up to 40%. The mode is a hint -- actual THP
# behavior depends on host kernel configuration.
#
# References:
#   - https://docs.kernel.org/admin-guide/mm/transhuge.html
#   - https://www.gnu.org/software/libc/manual/html_node/Memory-Allocation-Tunables.html
{ lib, ... }:
{
  options.performance.hugePages = lib.mkOption {
    type = lib.types.submodule {
      options = {
        thpMode = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "madvise"
              "always"
            ]
          );
          default = null;
          description = ''
            Transparent Huge Pages mode hint. Sets `glibc.malloc.hugetlb`
            tunable and generates an OCI label for host configuration.

            - `"madvise"` -- recommended for containers. Applications opt
              in to THP via `madvise(MADV_HUGEPAGE)`. Avoids compaction
              latency spikes from `always` mode. jemalloc and Go runtime
              use this automatically.

            - `"always"` -- kernel aggressively promotes to 2MB pages.
              Can cause latency spikes due to compaction. Best for
              large-heap, throughput-focused workloads (databases, ML).

            - `null` -- no THP hint (host default applies).
          '';
          example = "madvise";
        };

        glibcHugetlb = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              0
              1
              2
            ]
          );
          default = null;
          description = ''
            glibc `malloc.hugetlb` tunable value.

            - `0` -- disabled (default).
            - `1` -- use `MADV_HUGEPAGE` after mmap.
            - `2` -- use `MAP_HUGETLB` directly (requires hugetlbfs
              mounted and `ulimits.memlock` set to `"infinity"`).

            When `thpMode` is set and this is `null`, it is automatically
            derived: `"madvise"` → `1`, `"always"` → `1`.
          '';
          example = 1;
        };
      };
    };
    default = { };
    description = "Huge page configuration for reduced TLB misses and lower page walk latency.";
  };
}
