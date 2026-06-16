# NixOS config: Podman container runtime for integration testing.
{ ... }:
{
  virtualisation.podman = {
    enable = true;
    dockerSocket.enable = true;
  };
  virtualisation.containers.storage.settings.storage.driver = "overlay";
  environment.sessionVariables.DOCKER_HOST = "unix:///run/podman/podman.sock";
}
