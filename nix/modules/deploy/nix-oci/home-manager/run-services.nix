# Home-manager: forward autoStart containers to services.podman.containers.
# Loader dependency is wired via the podman quadlet's extraConfig.Unit
# (NOT via systemd.user.services, which would conflict with the quadlet file).
# When a healthcheck is present, Notify=healthy tells the quadlet to forward
# READY=1 after the first healthcheck passes.
#
# Healthcheck is injected via podman flags at runtime as a workaround for
# nix2container upstream bug #197 (Healthcheck dropped from image config).
{ ... }:
{
  flake.modules.homeManager.nix-oci-run-services =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.oci;
      deployLib = import ../../../../lib/deploy.nix { inherit lib; };
      autoStart = deployLib.autoStartContainers cfg.containers;
    in
    {
      config = lib.mkIf (cfg.enable && cfg.backend == "podman" && autoStart != { }) {
        services.podman = {
          enable = true;
          containers = lib.mapAttrs (
            name: container:
            let
              perfArgs = deployLib.mkPerfOpts container;
              healthArgs = deployLib.mkHealthcheckOpts container;
              hasHc = container.hasHealthcheck or false;
              allPodmanArgs = perfArgs ++ healthArgs;
            in
            {
              image = container.imageRef;
              extraConfig = {
                Unit = {
                  After = [ "oci-load-${name}.service" ];
                  Requires = [ "oci-load-${name}.service" ];
                };
              }
              // lib.optionalAttrs hasHc {
                Container = {
                  Notify = "healthy";
                };
                Service = {
                  Type = "notify";
                };
              };
            }
            // lib.optionalAttrs (container.ports != [ ]) {
              ports = container.ports;
            }
            // lib.optionalAttrs (container.environment != { }) {
              environment = container.environment;
            }
            // lib.optionalAttrs (container.volumes != [ ]) {
              volumes = container.volumes;
            }
            // lib.optionalAttrs (allPodmanArgs != [ ]) {
              extraPodmanArgs = allPodmanArgs;
            }
          ) autoStart;
        };
      };
    };
}
