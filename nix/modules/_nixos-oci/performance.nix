# Container performance: inner NixOS module contract.
#
# Mirrors hardening.nix pattern. It:
#   1. Defines `oci.container.performance.*` options (arch-independent subset)
#   2. Outputs build artifacts via `oci.container._output.performance.*`
#
# Arch-specific options (march, hwcaps) are handled by the image builder
# directly using archConfigs -- they don't need NixOS eval.
#
# Users can tune performance through their nixosConfig modules:
#   oci.containers.my-app.nixosConfig.modules = [
#     ({ ... }: { oci.container.performance.allocator = "jemalloc"; })
#   ];
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

  allocatorEnvVars =
    if cfg.allocator == "jemalloc" then
      let
        effectiveConf = jemallocDefaults // cfg.allocatorConfig;
        confStr = lib.concatStringsSep "," (lib.mapAttrsToList (k: v: "${k}:${v}") effectiveConf);
      in
      lib.optional (effectiveConf != { }) "MALLOC_CONF=${confStr}"
    else if cfg.allocator == "mimalloc" then
      lib.mapAttrsToList (k: v: "MIMALLOC_${k}=${v}") cfg.allocatorConfig
    else if cfg.allocator == "tcmalloc" then
      lib.mapAttrsToList (k: v: "TCMALLOC_${k}=${v}") cfg.allocatorConfig
    else
      [ ];
in
{
  # -- Option definitions (the contract) --

  options.oci.container.performance = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable container performance tuning.";
    };

    allocator = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "mimalloc"
          "tcmalloc"
          "jemalloc"
          "snmalloc"
        ]
      );
      default = null;
      description = "Alternative memory allocator injected via LD_PRELOAD.";
    };

    allocatorConfig = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Per-allocator tuning parameters (env var keys/values).";
    };

    glibcTunables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "glibc tunables for GLIBC_TUNABLES env var.";
    };

    glibcTunablesPreset = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.enum [
          "memory-constrained"
          "high-throughput"
          "balanced"
        ]
      );
      default = null;
      description = "Curated glibc tunables preset. Explicit glibcTunables override preset values.";
    };

    startup = lib.mkOption {
      type = lib.types.submodule {
        options = {
          ldSoCache = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Run ldconfig at build time to pre-build /etc/ld.so.cache.";
          };
          stackSize = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Thread stack size in KB (ulimit -s).";
          };
        };
      };
      default = { };
      description = "Startup optimization options.";
    };

    hugePages = lib.mkOption {
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
            description = "Transparent Huge Pages mode hint.";
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
            description = "glibc malloc.hugetlb tunable value (0/1/2).";
          };
        };
      };
      default = { };
      description = "Huge page configuration.";
    };

    compiler = lib.mkOption {
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
            description = "Link-Time Optimization mode.";
          };
          optimizeLevel = lib.mkOption {
            type = lib.types.enum [
              "O2"
              "O3"
              "Os"
            ];
            default = "O2";
            description = "GCC/Clang optimization level.";
          };
          noSemanticInterposition = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Pass -fno-semantic-interposition.";
          };
        };
      };
      default = { };
      description = "Compiler optimization flags.";
    };
  };

  config.assertions = lib.optionals cfg.enable [
    {
      assertion = !(cfg.allocator != null && cfg.allocatorConfig != { } && cfg.allocator == "snmalloc");
      message = ''
        nix-oci: `performance.allocator = "snmalloc"` but `allocatorConfig` is set.
        snmalloc has no runtime tunables. The config keys
        ${lib.concatStringsSep ", " (lib.attrNames cfg.allocatorConfig)} will be ignored.
        Fix: remove `allocatorConfig` or switch to an allocator that supports tuning
        (jemalloc, mimalloc, tcmalloc).
      '';
    }
    {
      assertion = !(cfg.allocator == null && cfg.allocatorConfig != { });
      message = ''
        nix-oci: `performance.allocatorConfig` is set but no `allocator` is selected.
        The config keys ${lib.concatStringsSep ", " (lib.attrNames cfg.allocatorConfig)} will be ignored.
        Fix: set `performance.allocator` to one of: mimalloc, tcmalloc, jemalloc, snmalloc.
      '';
    }
    {
      assertion =
        !(cfg.glibcTunablesPreset != null && cfg.allocator != null && cfg.allocator != "jemalloc");
      message = ''
        nix-oci: `performance.glibcTunablesPreset = "${toString cfg.glibcTunablesPreset}"` tunes
        glibc's built-in malloc, but `allocator = "${toString cfg.allocator}"` replaces it via
        LD_PRELOAD. The glibc tunables will have no effect on allocations.
        Fix: remove `glibcTunablesPreset` when using a non-glibc allocator, or remove the allocator.
      '';
    }
    {
      assertion = !(cfg.glibcTunables != { } && cfg.allocator != null && cfg.allocator != "jemalloc");
      message = ''
        nix-oci: explicit `performance.glibcTunables` are set but `allocator = "${toString cfg.allocator}"`
        replaces glibc malloc via LD_PRELOAD. The glibc tunables will have no effect.
        Fix: remove `glibcTunables` when using a non-glibc allocator, or remove the allocator.
      '';
    }
  ];

  # -- Build artifact outputs --

  options.oci.container._output.performance = {
    envVars = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      internal = true;
      readOnly = true;
      description = "Performance env vars as KEY=VALUE strings.";
      default = lib.optionals cfg.enable (
        lib.optional (
          allocatorMeta.package != null
        ) "LD_PRELOAD=${allocatorMeta.package}/lib/${allocatorMeta.soName}"
        ++ allocatorEnvVars
        ++ lib.optional (effectiveTunables != { }) "GLIBC_TUNABLES=${tunablesStr}"
        ++ lib.optional (cfg.startup.stackSize != null) "STACK_SIZE=${cfg.startup.stackSize}"
        ++ (
          let
            comp = cfg.compiler;
            flags =
              lib.optional (comp.optimizeLevel != "O2") "-${comp.optimizeLevel}"
              ++ lib.optional (comp.lto == "thin") "-flto=thin"
              ++ lib.optional (comp.lto == "full") "-flto"
              ++ lib.optional comp.noSemanticInterposition "-fno-semantic-interposition";
          in
          lib.optional (flags != [ ]) "NIX_CFLAGS_COMPILE=${lib.concatStringsSep " " flags}"
        )
      );
    };

    extraDeps = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      internal = true;
      readOnly = true;
      description = "Packages required by performance tuning (allocator libs).";
      default = lib.optionals cfg.enable (
        lib.optional (allocatorMeta.package != null) allocatorMeta.package
        ++ lib.optional cfg.startup.ldSoCache (
          pkgs.runCommand "ld-so-cache" { nativeBuildInputs = [ pkgs.glibc.bin ]; } ''
            mkdir -p $out/etc
            ldconfig -C $out/etc/ld.so.cache
          ''
        )
      );
    };

    labels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      internal = true;
      readOnly = true;
      description = "OCI labels encoding performance tuning hints.";
      default =
        let
          ns = "io.github.dauliac.nix-oci";
        in
        lib.optionalAttrs cfg.enable (
          {
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
          }
        );
    };
  };
}
