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
          # The test VM ships an in-cluster docker-registry on
          # localhost:5000; point NIX_OCI_REGISTRY at it so
          # `nix-oci-app-oci-push-*` services actually push to
          # something. Without it they abort with:
          #   ERROR: no registry configured. Set NIX_OCI_REGISTRY
          #   or CI_REGISTRY_IMAGE, or set OCI_DIR for a local push.
          Environment = [
            "DOCKER_HOST=unix:///run/podman/podman.sock"
            "NIX_OCI_REGISTRY=localhost:5000"
          ];
          # Loading a hardened example image via podman/docker inside the
          # VM writes several hundred MB of blobs before the service is
          # marked started. On a GitHub Actions runner this crosses the
          # 5-minute mark, so systemd terminates the load mid-write and
          # podman fails with "failed to write temporary file:
          # unexpected EOF". 15min gives the load room without stalling
          # a broken test forever.
          TimeoutStartSec = "15min";
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
