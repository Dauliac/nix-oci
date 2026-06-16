# NixOS test module: convert flake app scripts into systemd oneshot services.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  appScripts = config.testing.appScripts or { };
in
{
  options.testing.appScripts = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = { };
    internal = true;
    description = "Flake app attrsets injected by test-apps module.";
  };

  config = lib.mkIf (appScripts != { }) {
    systemd.services = lib.mapAttrs' (
      name: app:
      lib.nameValuePair "nix-oci-app-${name}" {
        description = "nix-oci app test: ${name}";
        after = [ "podman.socket" ];
        requires = [ "podman.socket" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = app.program;
          Environment = "DOCKER_HOST=unix:///run/podman/podman.sock";
          TimeoutStartSec = "5min";
        };
      }
    ) appScripts;

    environment.systemPackages = lib.mapAttrsToList (
      _name: app:
      pkgs.runCommand "app-wrapper-${_name}" { } ''
        mkdir -p $out/bin
        ln -s ${app.program} $out/bin/
      ''
    ) appScripts;
  };
}
