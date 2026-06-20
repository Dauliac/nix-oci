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
              to full LTO. Recommended for Clang.
            - `"full"` -- monolithic LTO: best optimization, slowest compile.
            - `null` -- no LTO.
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
              compute-intensive code.
            - `"Os"` -- optimize for size.
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
          '';
        };
      };
    };
    default = { };
    description = "Compiler optimization flags applied at container build time.";
  };
}
