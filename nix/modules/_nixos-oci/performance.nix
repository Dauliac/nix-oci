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

  # Explicit tunables override preset values.
  effectiveTunables = presetTunables // cfg.glibcTunables;

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
  };

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
      );
    };

    extraDeps = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      internal = true;
      readOnly = true;
      description = "Packages required by performance tuning (allocator libs).";
      default = lib.optionals cfg.enable (
        lib.optional (allocatorMeta.package != null) allocatorMeta.package
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
        );
    };
  };
}
