# Shared: transparent huge page and explicit huge page configuration.
#
# THP can reduce TLB misses by an order of magnitude and decrease
# page walk latency by up to 40%. The mode is a hint -- actual THP
# behavior depends on host kernel configuration.
#
# References:
#   - https://docs.kernel.org/admin-guide/mm/transhuge.html
#   - https://www.gnu.org/software/libc/manual/html_node/Memory-Allocation-Tunables.html
{
  lib,
  ...
}:
let
  exampleThp = "madvise";
in
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

            - `"madvise"` -- recommended for containers.
            - `"always"` -- aggressive, can cause compaction latency spikes.
            - `null` -- no THP hint (host default applies).
          '';
          example = exampleThp;
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
            - `2` -- use `MAP_HUGETLB` directly (requires hugetlbfs).
          '';
          example = 1;
        };
      };
    };
    default = { };
    description = "Huge page configuration for reduced TLB misses and lower page walk latency.";
  };
}
