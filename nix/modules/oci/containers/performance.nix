# Container performance options (flake-parts wrapper).
#
# Imports all shared performance option definitions from _options/performance/
# into the per-container module. Mirrors the hardening.nix wrapper pattern.
{ ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          imports = [
            ./_options/performance/enable.nix
            ./_options/performance/allocator.nix
            ./_options/performance/glibc-tunables.nix
            ./_options/performance/compression.nix
            ./_options/performance/march.nix
            ./_options/performance/hwcaps.nix
          ];
        };
    };
}
