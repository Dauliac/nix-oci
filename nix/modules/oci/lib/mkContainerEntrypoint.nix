# OCI mkContainerEntrypoint - Generate entrypoint wrapper from systemd service data
#
# Translates the NixOS systemd service definition into a container entrypoint
# shell script that:
# 1. Creates required directories (Runtime, State, Cache, Log)
# 2. Runs preStart scripts
# 3. Runs ExecStartPre commands
# 4. exec's the main process (ExecStart) as PID 1
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkContainerEntrypoint = {
        type = lib.types.functionTo lib.types.package;
        description = "Generate entrypoint wrapper script from systemd service data";
        file = "nix/modules/oci/lib/mkContainerEntrypoint.nix";
        fn =
          { serviceData }:
          let
            inherit (serviceData)
              runtimeDirs
              stateDirs
              cacheDirs
              logDirs
              preStart
              execStartPre
              execStart
              environment
              ;

            mkDirs = prefix: dirs: lib.concatMapStringsSep "\n" (d: "mkdir -p ${prefix}/${d}") dirs;

            mkEnvExports = lib.concatStringsSep "\n" (
              lib.mapAttrsToList (k: v: "export ${k}=${lib.escapeShellArg v}") environment
            );

            # Filter out null/empty entries from ExecStartPre
            validExecStartPre = builtins.filter (x: x != null && x != "") execStartPre;

            # ExecStartPre entries may have a "-" or "+" prefix (systemd: ignore exit code)
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

            ${lib.optionalString (runtimeDirs != [ ]) (mkDirs "/run" runtimeDirs)}
            ${lib.optionalString (stateDirs != [ ]) (mkDirs "/var/lib" stateDirs)}
            ${lib.optionalString (cacheDirs != [ ]) (mkDirs "/var/cache" cacheDirs)}
            ${lib.optionalString (logDirs != [ ]) (mkDirs "/var/log" logDirs)}
            ${lib.optionalString (mkEnvExports != "") mkEnvExports}
            ${lib.optionalString (preStart != "") preStart}
            ${lib.optionalString (mkExecStartPre != "") mkExecStartPre}

            # Main process - exec replaces shell, becomes PID 1
            exec ${execStart}
          '';
      };
    };
}
