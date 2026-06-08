# OCI mkNixOSExtract - Extract container artifacts from evaluated NixOS config
#
# Given an evaluated NixOS config and a mainService name, extracts:
# - Extra packages (from environment.systemPackages)
# - Service data (dirs, preStart, execStart, environment)
# - Users and groups (from users.users / users.groups)
#
# Note: We intentionally do NOT extract environment.etc because the full
# NixOS /etc tree includes hundreds of irrelevant files (PAM, sysctl,
# tmpfiles, SSH, etc.). Service config files are referenced by nix store
# paths in ExecStart and do not need to be in /etc.
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkNixOSExtract = {
        type = lib.types.functionTo lib.types.attrs;
        description = "Extract container artifacts from evaluated NixOS config";
        fn =
          {
            nixosConfig,
            mainService ? null,
          }:
          let
            cfg = nixosConfig;

            # Extract systemPackages as dependencies
            systemPackages = cfg.environment.systemPackages or [ ];

            # Extract service-specific data when mainService is set
            serviceData =
              if mainService != null then
                let
                  svc =
                    cfg.systemd.services.${mainService}
                      or (throw "NixOS service '${mainService}' not found in evaluated config");
                  sc = svc.serviceConfig or { };
                  toList =
                    x:
                    if builtins.isList x then
                      x
                    else if x == null then
                      [ ]
                    else
                      [ x ];
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
                }
              else
                null;

            # Extract users/groups
            users = cfg.users.users or { };
            groups = cfg.users.groups or { };
          in
          {
            inherit
              systemPackages
              serviceData
              users
              groups
              ;
          };
      };
    };
}
