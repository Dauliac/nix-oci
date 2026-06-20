# NixOS-only entrypoint options: service adapter integration.
#
# Shared options (entrypoint, stopSignal, workingDir, declaredVolumes)
# come from _options/ via container-options-namespace.nix.
# These NixOS-only options are set by service adapters during NixOS eval.
{ lib, ... }:
{
  options.oci.container = {
    mainService = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Logical NixOS service name to extract entrypoint from.
        For most services this matches the systemd unit name directly.
        For multi-instance services (e.g. redis), the service adapter
        resolves this to the actual systemd unit name automatically.
      '';
    };
    resolvedSystemdServiceName = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Resolved systemd service name. Set by service adapters for
        multi-instance services where the logical name differs from
        the systemd unit name (e.g. "redis" → "redis-default").
        When null, falls back to mainService.
      '';
    };
    resolvedServicePackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        Resolved service package. Set by service adapters for services
        where config.services.<name>.package doesn't exist at the top
        level (e.g. redis package is under servers.<name>).
      '';
    };
    resolvedServiceDataDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Resolved service data directory. Set by service adapters for
        services where config.services.<name>.dataDir doesn't exist
        at the top level.
      '';
    };
  };
}
