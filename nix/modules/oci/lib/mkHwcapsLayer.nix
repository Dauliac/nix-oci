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
            level, # e.g. "x86-64-v3"
            libraries, # list of packages to rebuild
          }:
          let
            # Create a stdenv targeting the specific march level
            optimizedStdenv = pkgs.stdenvAdapters.withCFlags [
              "-march=${level}"
              "-mtune=${level}"
            ] pkgs.stdenv;

            # Rebuild each library and extract only .so files
            optimizedLibs = map (
              pkg:
              let
                rebuilt = pkg.override { stdenv = optimizedStdenv; };
              in
              pkgs.runCommand "${pkg.pname or pkg.name}-hwcaps-${level}" { } ''
                mkdir -p $out/lib/glibc-hwcaps/${level}
                for so in $(find ${rebuilt}/lib -name '*.so*' -type f 2>/dev/null); do
                  cp -L "$so" $out/lib/glibc-hwcaps/${level}/
                done
              ''
            ) libraries;

            hwcapsRoot = pkgs.buildEnv {
              name = "hwcaps-${level}";
              paths = optimizedLibs;
              pathsToLink = [ "/lib/glibc-hwcaps" ];
            };
          in
          nix2container.buildLayer { copyToRoot = [ hwcapsRoot ]; };
      };
    };
}
