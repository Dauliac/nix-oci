# NixOS test module: convert flake app scripts into systemd oneshot services.
#
# Each app (policy-conftest, lint-dockle, sbom-syft, etc.) becomes a
# systemd oneshot service that can be started and validated by the
# Python test harness. This keeps the NixOS ceremony (systemd units,
# service dependencies) in the NixOS module where it belongs.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.testing;
in
{
  options.testing.appScripts = lib.mkOption {
    type = lib.types.attrsOf lib.types.attrs;
    default = { };
    internal = true;
    description = ''
      Flake app attrsets to expose as systemd oneshot services.
      Each entry has { type = "app"; program = "/nix/store/..."; }.
      Injected by the flake-parts test-apps module.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.appScripts != { }) {
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
    ) cfg.appScripts;

    # Ensure all app script store paths are available in the VM
    environment.systemPackages = lib.mapAttrsToList (
      _name: app:
      let
        # Extract the package from the program path
        storePath = builtins.dirOf (builtins.dirOf app.program);
      in
      pkgs.runCommand "app-wrapper-${_name}" { } ''
        mkdir -p $out/bin
        ln -s ${app.program} $out/bin/
      ''
    ) cfg.appScripts;
  };
}
