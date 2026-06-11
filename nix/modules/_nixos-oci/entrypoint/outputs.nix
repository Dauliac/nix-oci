# Computed entrypoint outputs + assertions.
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container;

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

  effectiveSystemdName =
    if cfg.resolvedSystemdServiceName != null then cfg.resolvedSystemdServiceName else cfg.mainService;
in
{
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
    {
      assertion =
        let
          svcName = effectiveSystemdName;
        in
        svcName == null || config.systemd.services ? ${svcName};
      message = ''
        nix-oci: `mainService = "${toString cfg.mainService}"` but no systemd service
        "${toString effectiveSystemdName}" exists in the NixOS evaluation.
        This usually means:
          - The service module is not enabled (add `services.${toString cfg.mainService}.enable = true`)
          - The service name is misspelled
          - The service uses a different systemd unit name (check with a service adapter)
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
