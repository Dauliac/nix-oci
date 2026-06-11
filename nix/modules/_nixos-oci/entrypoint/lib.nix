# Internal library functions for entrypoint extraction.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  ociLib = import ../../../lib/oci.nix { inherit lib; };
in
{
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
}
