# Container performance: inner NixOS module contract.
#
# Mirrors hardening.nix pattern. It:
#   1. Defines `oci.container.performance.*` options (arch-independent subset)
#   2. Outputs build artifacts via `oci.container._output.performance.*`
#
# Arch-specific options (march, hwcaps) are handled by the image builder
# directly using archConfigs — they don't need NixOS eval.
#
# Users can tune performance through their nixosConfig modules:
#   oci.containers.my-app.nixosConfig.modules = [
#     ({ ... }: { oci.container.performance.allocator = "mimalloc"; })
#   ];
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container.performance;

  allocatorMeta =
    if cfg.allocator == "mimalloc" then
      {
        package = pkgs.mimalloc;
        soName = "libmimalloc.so";
      }
    else if cfg.allocator == "tcmalloc" then
      {
        package = pkgs.gperftools;
        soName = "libtcmalloc.so";
      }
    else
      {
        package = null;
        soName = null;
      };

  tunablesStr = lib.concatStringsSep ":" (
    lib.mapAttrsToList (name: value: "${name}=${value}") cfg.glibcTunables
  );
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
        ]
      );
      default = null;
      description = "Alternative memory allocator injected via LD_PRELOAD.";
    };

    glibcTunables = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "glibc tunables for GLIBC_TUNABLES env var.";
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
        ++ lib.optional (cfg.glibcTunables != { }) "GLIBC_TUNABLES=${tunablesStr}"
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
          // lib.optionalAttrs (cfg.glibcTunables != { }) {
            "${ns}.performance.glibc-tunables" = lib.concatStringsSep "," (lib.attrNames cfg.glibcTunables);
          }
        );
    };
  };
}
