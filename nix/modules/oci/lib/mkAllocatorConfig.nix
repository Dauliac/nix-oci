# nix-lib: resolve allocator package + soName and glibc tunables from config.
#
# Pure function that maps allocator name → { package, soName } and
# expands glibc tunables presets into concrete tunable key-value pairs.
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      allocatorMap = {
        mimalloc = {
          package = pkgs.mimalloc;
          soName = "libmimalloc.so";
        };
        tcmalloc = {
          package = pkgs.gperftools;
          soName = "libtcmalloc.so";
        };
        jemalloc = {
          package = pkgs.jemalloc;
          soName = "libjemalloc.so";
        };
        snmalloc = {
          package = pkgs.snmalloc;
          soName = "libsnmallocshim.so";
        };
      };

      presetMap = {
        "memory-constrained" = {
          "glibc.malloc.arena_max" = "2";
          "glibc.malloc.trim_threshold" = "32768";
          "glibc.malloc.top_pad" = "0";
          "glibc.malloc.mmap_threshold" = "65536";
          "glibc.malloc.tcache_count" = "3";
        };
        "high-throughput" = {
          "glibc.malloc.arena_max" = "8";
          "glibc.malloc.tcache_count" = "15";
          "glibc.malloc.mxfast" = "256";
        };
        "balanced" = {
          "glibc.malloc.arena_max" = "4";
          "glibc.malloc.trim_threshold" = "131072";
          "glibc.malloc.mmap_threshold" = "131072";
          "glibc.malloc.tcache_count" = "7";
        };
      };
    in
    {
      nix-lib.lib.oci.mkAllocatorConfig = {
        type = lib.types.functionTo lib.types.attrs;
        description = ''
          Resolve allocator and glibc tunables from performance config.

          Returns:
            {
              allocatorPackage  — package or null
              allocatorSoName   — string or null (for LD_PRELOAD)
              glibcTunables     — attrset of tunable key-value pairs
            }
        '';
        file = "nix/modules/oci/lib/mkAllocatorConfig.nix";
        fn =
          { performance }:
          let
            cfg = performance;
            allocatorMeta =
              if cfg.allocator or null != null then
                allocatorMap.${cfg.allocator}
              else
                {
                  package = null;
                  soName = null;
                };
            presetTunables =
              if cfg.glibcTunablesPreset or null != null then
                presetMap.${cfg.glibcTunablesPreset}
              else
                { };
            mergedTunables = presetTunables // (cfg.glibcTunables or { });
          in
          {
            allocatorPackage = allocatorMeta.package;
            allocatorSoName = allocatorMeta.soName;
            glibcTunables = mergedTunables;
          };
      };
    };
}
