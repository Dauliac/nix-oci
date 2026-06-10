# Entrypoint: options, lib functions, and outputs for service-based entrypoints
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container;
  ociLib = import ../../lib/oci.nix { inherit lib; };

  # POSIX signals valid for OCI StopSignal.
  validSignals = [
    "SIGABRT"
    "SIGALRM"
    "SIGBUS"
    "SIGCHLD"
    "SIGCONT"
    "SIGFPE"
    "SIGHUP"
    "SIGILL"
    "SIGINT"
    "SIGIO"
    "SIGIOT"
    "SIGKILL"
    "SIGPIPE"
    "SIGPOLL"
    "SIGPROF"
    "SIGPWR"
    "SIGQUIT"
    "SIGSEGV"
    "SIGSTKFLT"
    "SIGSTOP"
    "SIGSYS"
    "SIGTERM"
    "SIGTRAP"
    "SIGTSTP"
    "SIGTTIN"
    "SIGTTOU"
    "SIGURG"
    "SIGUSR1"
    "SIGUSR2"
    "SIGVTALRM"
    "SIGWINCH"
    "SIGXCPU"
    "SIGXFSZ"
  ];
  # Effective names used for all lookups -- adapters override these for
  # multi-instance services (e.g. redis "redis" → "redis-default").
  effectiveSystemdName =
    if cfg.resolvedSystemdServiceName != null then cfg.resolvedSystemdServiceName else cfg.mainService;
in
{
  options.oci.container = {
    entrypoint = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
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
      description = "Graceful stop signal. Set by service adapters or auto-derived from systemd KillSignal.";
    };
    workingDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Working directory. Auto-derived from systemd WorkingDirectory, service dataDir, or user home.";
    };
    declaredVolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional OCI volume mount points (merged with auto-derived from systemd directories).";
    };
  };

  options.oci.lib = {
    toList = lib.mkOption {
      type = lib.types.unspecified;
      internal = true;
      readOnly = true;
      description = "Normalize a value to a list (handles null, scalar, list).";
      default = ociLib.toList;
    };

    extractServiceData = lib.mkOption {
      type = lib.types.unspecified;
      internal = true;
      readOnly = true;
      description = "Extract service data from a systemd unit.";
      default =
        serviceName:
        let
          svc = config.systemd.services.${serviceName};
          sc = svc.serviceConfig or { };
          toList = config.oci.lib.toList;
        in
        {
          runtimeDirs = toList (sc.RuntimeDirectory or null);
          stateDirs = toList (sc.StateDirectory or null);
          cacheDirs = toList (sc.CacheDirectory or null);
          logDirs = toList (sc.LogsDirectory or null);
          preStart = svc.preStart or "";
          execStartPre = toList (sc.ExecStartPre or null);
          execStart =
            let
              raw = sc.ExecStart or null;
            in
            if builtins.isList raw then
              let
                parts = builtins.filter (x: x != null && x != "") raw;
              in
              if parts == [ ] then null else lib.concatStringsSep " " parts
            else
              raw;
          serviceType = sc.Type or "simple";
          environment = svc.environment or { };
          killSignal = sc.KillSignal or null;
          workingDirectory = sc.WorkingDirectory or null;
        };
    };

    mkEntrypointScript = lib.mkOption {
      type = lib.types.unspecified;
      internal = true;
      readOnly = true;
      description = "Generate an entrypoint wrapper script from systemd service data.";
      default = serviceData: ociLib.mkEntrypointScript { inherit serviceData pkgs; };
    };
  };

  config.assertions = [
    {
      assertion =
        !(cfg.mainService == null && cfg.entrypoint == [ ] && config.oci.container.package == null);
      message = ''
        nix-oci: container has no entrypoint. None of the following are set:
          - `mainService` (auto-derives entrypoint from a NixOS service)
          - `entrypoint` (explicit command list)
          - `package` (package with meta.mainProgram)
        At least one must be set to produce a runnable container image.
      '';
    }
    {
      assertion =
        let
          sd = cfg._output.serviceData;
          hasServiceEntrypoint = sd != null && sd.execStart != null;
        in
        !(cfg.mainService != null && cfg.entrypoint != [ ] && hasServiceEntrypoint);
      message = ''
        nix-oci: both `mainService = "${toString cfg.mainService}"` and an explicit
        `entrypoint` are set. The service-derived entrypoint takes precedence and
        the explicit entrypoint will be silently ignored.
        Fix: remove the explicit `entrypoint` or remove `mainService`.
      '';
    }
    {
      assertion =
        let
          effectiveStop = cfg._output.stopSignal;
        in
        effectiveStop == null || lib.elem effectiveStop validSignals;
      message = ''
        nix-oci: invalid stopSignal "${toString cfg._output.stopSignal}".
        Must be a valid POSIX signal name (e.g. SIGTERM, SIGQUIT, SIGINT).
        Valid values: ${lib.concatStringsSep ", " validSignals}
      '';
    }
  ];

  options.oci.container._output = {
    serviceData = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      internal = true;
      readOnly = true;
      default =
        if effectiveSystemdName != null then
          config.oci.lib.extractServiceData effectiveSystemdName
        else
          null;
    };

    servicePackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      internal = true;
      readOnly = true;
      default =
        if cfg.resolvedServicePackage != null then
          cfg.resolvedServicePackage
        else if cfg.mainService != null then
          config.services.${cfg.mainService}.package or null
        else
          null;
    };

    entrypoint = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      internal = true;
      readOnly = true;
      default =
        let
          sd = cfg._output.serviceData;
        in
        if sd != null && sd.execStart != null then
          [ "${config.oci.lib.mkEntrypointScript sd}" ]
        else
          cfg.entrypoint;
    };

    stopSignal = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      internal = true;
      readOnly = true;
      description = "Graceful stop signal derived from systemd KillSignal or service adapter.";
      default =
        let
          sd = cfg._output.serviceData;
          fromSystemd = if sd != null then sd.killSignal else null;
        in
        if cfg.stopSignal != null then cfg.stopSignal else fromSystemd;
    };

    workingDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      internal = true;
      readOnly = true;
      description = "Working directory derived from systemd WorkingDirectory, service dataDir, or user home.";
      default =
        let
          sd = cfg._output.serviceData;
          fromSystemd = if sd != null then sd.workingDirectory else null;
          fromService =
            if cfg.resolvedServiceDataDir != null then
              cfg.resolvedServiceDataDir
            else if cfg.mainService != null then
              config.services.${cfg.mainService}.dataDir or null
            else
              null;
        in
        if cfg.workingDir != null then
          cfg.workingDir
        else if fromSystemd != null then
          fromSystemd
        else if fromService != null then
          fromService
        else
          config.oci.lib.homeDir;
    };

    declaredVolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      internal = true;
      readOnly = true;
      description = "OCI volume mount points derived from systemd StateDirectory, RuntimeDirectory, etc.";
      default =
        let
          sd = cfg._output.serviceData;
        in
        if sd != null then
          (map (d: "/run/${d}") sd.runtimeDirs)
          ++ (map (d: "/var/lib/${d}") sd.stateDirs)
          ++ (map (d: "/var/cache/${d}") sd.cacheDirs)
          ++ (map (d: "/var/log/${d}") sd.logDirs)
          ++ cfg.declaredVolumes
        else
          cfg.declaredVolumes;
    };
  };
}
