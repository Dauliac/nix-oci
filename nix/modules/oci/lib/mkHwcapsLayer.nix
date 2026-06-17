# nix-lib: build a glibc-hwcaps layer for a specific microarchitecture level.
#
# Rebuilds the given libraries with -march=<level> and installs only
# their .so files into /lib/glibc-hwcaps/<level>/. The dynamic linker
# selects the best available variant at process startup.
#
# References:
#   - https://www.phoronix.com/news/Glibc-2.33-Coming-HWCAPS
#   - https://www.clearlinux.org/blogs/transparent-use-library-packages-optimized-intel-architecture.html
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkHwcapsLayer = {
        type = lib.types.functionTo lib.types.package;
        description = ''
          Build a nix2container layer containing CPU-optimized shared libraries
          for a specific x86-64 microarchitecture level.

          The dynamic linker selects the best available variant at process
          startup based on CPUID -- zero application changes required.
        '';
        file = "nix/modules/oci/lib/mkHwcapsLayer.nix";
        fn =
          {
            nix2container,
            level,
            libraries,
          }:
          pure.mkHwcapsLayer {
            inherit
              pkgs
              nix2container
              level
              libraries
              ;
          };
      };
    };
}
