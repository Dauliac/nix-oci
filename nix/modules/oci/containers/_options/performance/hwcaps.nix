# Shared: container-level glibc-hwcaps (sugar).
#
# This is container-level sugar that flows down to the per-arch
# config via mkDefault. The canonical per-arch option lives in
# _archOptions/performance/hwcaps.nix.
#
# For single-arch containers, this is all you need.
# For multi-arch, override per-arch via archConfigs.
#
# References:
#   - https://www.phoronix.com/news/Glibc-2.33-Coming-HWCAPS
#   - https://www.clearlinux.org/blogs/transparent-use-library-packages-optimized-intel-architecture.html
{
  lib,
  pkgs,
  ...
}:
{
  options.performance.hwcaps = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Build and ship CPU-optimized library variants via glibc-hwcaps.

            The dynamic linker selects the best variant at process startup
            based on CPUID -- zero application changes required.

            Only effective on systems with hwcaps support (x86_64-linux).
            Auto-disabled on unsupported architectures in per-arch config.
          '';
        };

        levels = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Microarchitecture levels to build optimized libraries for.
            Valid values depend on the target system:
            - **x86_64-linux**: `"x86-64-v2"`, `"x86-64-v3"`, `"x86-64-v4"`

            The baseline is always included as fallback (not listed here).
          '';
          example = [ "x86-64-v3" ];
        };

        libraries = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = ''
            Packages whose shared libraries to rebuild at each hwcaps level.
            Only `.so` files are extracted into the hwcaps layer.

            Good candidates: crypto (openssl), compression (zlib, zstd),
            math-heavy libraries, string processing.
          '';
          example = lib.literalExpression "[ pkgs.openssl pkgs.zlib ]";
        };
      };
    };
    default = { };
    description = "glibc-hwcaps: ship CPU-optimized library variants selected at runtime.";
  };
}
