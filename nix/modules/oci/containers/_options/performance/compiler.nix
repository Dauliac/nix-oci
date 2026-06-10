# Shared: compiler optimization flags for container packages.
#
# These flags are applied via NIX_CFLAGS_COMPILE in the NixOS container
# eval. Only effective for packages built from source (not cached binaries).
#
# References:
#   - https://wiki.gentoo.org/wiki/LTO
#   - https://clang.llvm.org/docs/ThinLTO.html
{ lib, ... }:
{
  options.performance.compiler = lib.mkOption {
    type = lib.types.submodule {
      options = {
        lto = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "thin"
              "full"
            ]
          );
          default = null;
          description = ''
            Link-Time Optimization mode.

            - `"thin"` -- ThinLTO: fast compile, nearly equal performance
              to full LTO. Recommended for Clang. Splits analysis into
              parallel units.
            - `"full"` -- monolithic LTO: best optimization, slowest compile.
              Analyzes entire link unit at once.
            - `null` -- no LTO.

            > **Warning**: LTO causes full rebuilds of affected packages
            > (no binary cache hits). Only use for performance-critical
            > containers where rebuild time is acceptable.
          '';
          example = "thin";
        };

        optimizeLevel = lib.mkOption {
          type = lib.types.enum [
            "O2"
            "O3"
            "Os"
          ];
          default = "O2";
          description = ''
            GCC/Clang optimization level.

            - `"O2"` -- safe default, good performance.
            - `"O3"` -- aggressive optimization, ~5-15% faster for
              compute-intensive code. May increase binary size and
              I-cache pressure.
            - `"Os"` -- optimize for size. May be faster than O2 for
              I-cache-bound workloads due to smaller code footprint.
          '';
          example = "O3";
        };

        noSemanticInterposition = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Pass `-fno-semantic-interposition` to GCC/Clang.

            Tells the compiler that functions in shared libraries won't
            be overridden by `LD_PRELOAD`, enabling inlining and
            devirtualization within the DSO. 5-10% improvement for
            library-heavy code.

            > **Note**: incompatible with LD_PRELOAD-based allocator
            > injection for the affected libraries. The allocator
            > LD_PRELOAD still works for the main binary.
          '';
        };
      };
    };
    default = { };
    description = "Compiler optimization flags applied at container build time.";
  };
}
