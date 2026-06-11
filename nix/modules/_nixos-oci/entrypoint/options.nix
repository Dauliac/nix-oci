# User-facing entrypoint options for container service extraction.
{ lib, ... }:
{
  options.oci.container = {
    entrypoint = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      defaultText = lib.literalMD ''
        Auto-derived from `mainService` systemd `ExecStart` when set.
      '';
      description = "Container entrypoint. Auto-derived from mainService when set.";
    };
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
    stopSignal = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      defaultText = lib.literalMD ''
        Auto-derived (strongest to weakest):
        1. service adapter signal (e.g. `SIGQUIT` for nginx, `SIGINT` for PostgreSQL)
        2. systemd `KillSignal`
        3. container runtime default (`SIGTERM`)
      '';
      description = "Graceful stop signal. Set by service adapters or auto-derived from systemd KillSignal.";
    };
    workingDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      defaultText = lib.literalMD ''
        Auto-derived (strongest to weakest):
        1. systemd `WorkingDirectory`
        2. service `dataDir` (e.g. `/var/lib/postgresql`)
        3. user home directory (`/root` or `/home/<user>`)
      '';
      description = "Working directory. Auto-derived from systemd WorkingDirectory, service dataDir, or user home.";
    };
    declaredVolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      defaultText = lib.literalMD ''
        Auto-derived from systemd service directories:
        - `StateDirectory` → `/var/lib/<dir>`
        - `RuntimeDirectory` → `/run/<dir>`
        - `CacheDirectory` → `/var/cache/<dir>`
        - `LogsDirectory` → `/var/log/<dir>`
      '';
      description = "Additional OCI volume mount points (merged with auto-derived from systemd directories).";
    };
  };
}
