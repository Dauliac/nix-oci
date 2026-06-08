# Entrypoint: options, lib functions, and outputs for service-based entrypoints
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container;
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
      description = "NixOS service to extract entrypoint from.";
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
      default =
        x:
        if builtins.isList x then
          x
        else if x == null then
          [ ]
        else
          [ x ];
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
          execStart = sc.ExecStart or null;
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
      default =
        serviceData:
        let
          mkDirs = prefix: dirs: lib.concatMapStringsSep "\n" (d: "mkdir -p ${prefix}/${d}") dirs;
          mkEnvExports = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") serviceData.environment
          );
          validExecStartPre = builtins.filter (x: x != null && x != "") serviceData.execStartPre;
          mkExecStartPre = lib.concatMapStringsSep "\n" (
            cmd:
            let
              stripped = lib.removePrefix "-" (lib.removePrefix "+" cmd);
              ignoreFailure = lib.hasPrefix "-" cmd || lib.hasPrefix "+" cmd;
            in
            if ignoreFailure then "${stripped} || true" else stripped
          ) validExecStartPre;
        in
        pkgs.writeShellScript "container-entrypoint" ''
          set -euo pipefail
          ${lib.optionalString (serviceData.runtimeDirs != [ ]) (mkDirs "/run" serviceData.runtimeDirs)}
          ${lib.optionalString (serviceData.stateDirs != [ ]) (mkDirs "/var/lib" serviceData.stateDirs)}
          ${lib.optionalString (serviceData.cacheDirs != [ ]) (mkDirs "/var/cache" serviceData.cacheDirs)}
          ${lib.optionalString (serviceData.logDirs != [ ]) (mkDirs "/var/log" serviceData.logDirs)}
          ${lib.optionalString (mkEnvExports != "") mkEnvExports}
          ${lib.optionalString (serviceData.preStart != "") serviceData.preStart}
          ${lib.optionalString (mkExecStartPre != "") mkExecStartPre}
          exec ${serviceData.execStart}
        '';
    };
  };

  options.oci.container._output = {
    serviceData = lib.mkOption {
      type = lib.types.nullOr lib.types.attrs;
      internal = true;
      readOnly = true;
      default =
        if cfg.mainService != null then config.oci.lib.extractServiceData cfg.mainService else null;
    };

    servicePackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      internal = true;
      readOnly = true;
      default =
        if cfg.mainService != null then config.services.${cfg.mainService}.package or null else null;
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
            if cfg.mainService != null then config.services.${cfg.mainService}.dataDir or null else null;
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
