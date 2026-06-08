# Per-architecture: glibc-hwcaps CPU-optimized library layers.
#
# Only effective on systems with hwcaps support (x86_64-linux).
# Auto-disabled on unsupported architectures via the perArchitecture
# contribution in multiArch/archPerformance.nix.
#
# References:
#   - https://www.phoronix.com/news/Glibc-2.33-Coming-HWCAPS
#   - https://www.clearlinux.org/blogs/transparent-use-library-packages-optimized-intel-architecture.html
{ lib, ... }:
{
  options.performance.hwcaps = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Ship CPU-optimized library variants via glibc-hwcaps for this arch.

            Only effective on systems where `archMap.microarch.hwcapsSupported`
            is true (currently x86_64-linux).
          '';
        };

        levels = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Microarchitecture levels to build optimized libraries for.
            Valid values depend on the target system:
            - **x86_64-linux**: `"x86-64-v2"`, `"x86-64-v3"`, `"x86-64-v4"`

            The baseline is always included as fallback.
          '';
          example = [ "x86-64-v3" ];
        };

        libraries = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = ''
            Packages whose `.so` files to rebuild at each hwcaps level.
          '';
          example = lib.literalExpression "[ pkgs.openssl pkgs.zlib ]";
        };
      };
    };
    default = { };
    description = "glibc-hwcaps: automatic CPU-optimized library selection for this arch.";
  };
}
