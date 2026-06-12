# NixOS config: Podman container runtime for integration testing.
{
  config,
  lib,
  ...
}:
let
  cfg = config.testing;
in
lib.mkIf cfg.enable {
  virtualisation.podman = {
    enable = true;
    dockerSocket.enable = true;
  };
  virtualisation.containers.storage.settings.storage.driver = "overlay";
  environment.sessionVariables.DOCKER_HOST = "unix:///run/podman/podman.sock";
  environment.systemPackages = cfg.extraPackages;
}
