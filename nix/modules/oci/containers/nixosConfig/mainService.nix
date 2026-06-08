# Container nixosConfig.mainService option
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.nixosConfig.mainService = mkOption {
            type = types.nullOr types.str;
            description = ''
              The NixOS service that this container runs.

              When set, the container's package is auto-derived from the service
              module's package option, and an entrypoint wrapper script is
              generated from the service's systemd unit (preStart, ExecStartPre,
              ExecStart, directory creation).

              Cannot be set together with `package` - they are mutually exclusive
              sources for the container's main program.

              When null, `nixosConfig` only provides config files, users/groups,
              and extra packages (environment.systemPackages) as dependencies.
            '';
            default = null;
            example = "nginx";
          };
        };
    };
}
