# Performance outputs: allocator injection, glibc tunables, compiler flags.
#
# Uses NixOS-native routing:
#   - environment.variables for env vars (LD_PRELOAD, MALLOC_CONF, GLIBC_TUNABLES, etc.)
#   - oci.container.extraPackages for allocator libraries
#   - oci.container.generatedLabels for OCI metadata
#
# The previous pattern of custom _output.performance.{envVars,extraDeps,labels}
# is replaced by these unified options.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container.performance;

  # -- Allocator package + soName mapping --
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
  allocatorMeta =
    if cfg.allocator != null then
      allocatorMap.${cfg.allocator}
    else
      {
        package = null;
        soName = null;
      };

  # -- glibc tunables preset expansion --
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
  presetTunables =
    if cfg.glibcTunablesPreset != null then presetMap.${cfg.glibcTunablesPreset} else { };

  # Derive glibc.malloc.hugetlb from hugePages config
  hugePagesHugetlb =
    if cfg.hugePages.glibcHugetlb != null then
      cfg.hugePages.glibcHugetlb
    else if cfg.hugePages.thpMode != null then
      1
    else
      null;

  hugepageTunables = lib.optionalAttrs (hugePagesHugetlb != null) {
    "glibc.malloc.hugetlb" = toString hugePagesHugetlb;
  };

  # Explicit tunables override preset values.
  effectiveTunables = presetTunables // hugepageTunables // cfg.glibcTunables;

  tunablesStr = lib.concatStringsSep ":" (
    lib.mapAttrsToList (name: value: "${name}=${value}") effectiveTunables
  );

  # -- Per-allocator env var generation --
  #
  # jemalloc: MALLOC_CONF (colon-joined key:value)
  # mimalloc: MIMALLOC_<KEY>=<value> (one env var per key)
  # tcmalloc: TCMALLOC_<KEY>=<value> (one env var per key)
  # snmalloc: no runtime tunables
  #
  # jemalloc container safety: inject muzzy_decay_ms:0 by default to prevent
  # MADV_FREE from inflating cgroup RSS. Users can override explicitly.
  jemallocDefaults = {
    "muzzy_decay_ms" = "0";
    "background_thread" = "true";
    "abort_conf" = "true";
  };

  # Compiler flags
  comp = cfg.compiler;
  compilerFlags =
    lib.optional (comp.optimizeLevel != "O2") "-${comp.optimizeLevel}"
    ++ lib.optional (comp.lto == "thin") "-flto=thin"
    ++ lib.optional (comp.lto == "full") "-flto"
    ++ lib.optional comp.noSemanticInterposition "-fno-semantic-interposition";

  # Label namespace
  ns = "io.github.dauliac.nix-oci";
in
{
  # Backward-compat: old consumers read _output.performance.{envVars,extraDeps,labels}.
  # These aliases read from the new unified options. Remove after Phase 5/6 migration.
  options.oci.container._output.performance = {
    envVars = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      internal = true;
      readOnly = true;
      description = "DEPRECATED: use environment.variables. Kept for backward compat.";
      default = [ ];
    };
    extraDeps = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      internal = true;
      readOnly = true;
      description = "DEPRECATED: use oci.container.extraPackages. Kept for backward compat.";
      default = [ ];
    };
    labels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      internal = true;
      readOnly = true;
      description = "DEPRECATED: use oci.container.generatedLabels. Kept for backward compat.";
      default = config.oci.container.generatedLabels;
    };
  };

  config = lib.mkIf cfg.enable {
    # -- Environment variables (NixOS-native routing) --
    environment.variables =
      lib.optionalAttrs (allocatorMeta.package != null) {
        LD_PRELOAD = "${allocatorMeta.package}/lib/${allocatorMeta.soName}";
      }
      // (
        if cfg.allocator == "jemalloc" then
          let
            effectiveConf = jemallocDefaults // cfg.allocatorConfig;
            confStr = lib.concatStringsSep "," (lib.mapAttrsToList (k: v: "${k}:${v}") effectiveConf);
          in
          lib.optionalAttrs (effectiveConf != { }) { MALLOC_CONF = confStr; }
        else if cfg.allocator == "mimalloc" then
          lib.mapAttrs' (k: v: lib.nameValuePair "MIMALLOC_${k}" v) cfg.allocatorConfig
        else if cfg.allocator == "tcmalloc" then
          lib.mapAttrs' (k: v: lib.nameValuePair "TCMALLOC_${k}" v) cfg.allocatorConfig
        else
          { }
      )
      // lib.optionalAttrs (effectiveTunables != { }) {
        GLIBC_TUNABLES = tunablesStr;
      }
      // lib.optionalAttrs (cfg.startup.stackSize != null) {
        STACK_SIZE = cfg.startup.stackSize;
      }
      // lib.optionalAttrs (compilerFlags != [ ]) {
        NIX_CFLAGS_COMPILE = lib.concatStringsSep " " compilerFlags;
      };

    # -- Extra packages (unified routing) --
    oci.container.extraPackages =
      lib.optional (allocatorMeta.package != null) allocatorMeta.package
      ++ lib.optional cfg.startup.ldSoCache (
        pkgs.runCommand "ld-so-cache" { nativeBuildInputs = [ pkgs.glibc.bin ]; } ''
          mkdir -p $out/etc
          ldconfig -C $out/etc/ld.so.cache
        ''
      );

    # -- Generated labels (unified routing) --
    oci.container.generatedLabels = {
      "${ns}.performance.enabled" = "true";
    }
    // lib.optionalAttrs (cfg.allocator != null) {
      "${ns}.performance.allocator" = cfg.allocator;
    }
    // lib.optionalAttrs (cfg.allocatorConfig != { }) {
      "${ns}.performance.allocator-config" = lib.concatStringsSep "," (lib.attrNames cfg.allocatorConfig);
    }
    // lib.optionalAttrs (effectiveTunables != { }) {
      "${ns}.performance.glibc-tunables" = lib.concatStringsSep "," (lib.attrNames effectiveTunables);
    }
    // lib.optionalAttrs (cfg.glibcTunablesPreset != null) {
      "${ns}.performance.glibc-tunables-preset" = cfg.glibcTunablesPreset;
    }
    // lib.optionalAttrs (cfg.compiler.lto != null) {
      "${ns}.performance.compiler.lto" = cfg.compiler.lto;
    }
    // lib.optionalAttrs (cfg.compiler.optimizeLevel != "O2") {
      "${ns}.performance.compiler.optimize-level" = cfg.compiler.optimizeLevel;
    }
    // lib.optionalAttrs cfg.compiler.noSemanticInterposition {
      "${ns}.performance.compiler.no-semantic-interposition" = "true";
    }
    // lib.optionalAttrs (cfg.hugePages.thpMode != null) {
      "${ns}.performance.huge-pages.thp-mode" = cfg.hugePages.thpMode;
    }
    // lib.optionalAttrs cfg.startup.ldSoCache {
      "${ns}.performance.startup.ld-so-cache" = "true";
    }
    // lib.optionalAttrs (cfg.startup.stackSize != null) {
      "${ns}.performance.startup.stack-size" = cfg.startup.stackSize;
    };
  };
}
