# System-manager: run autoStart containers via direct systemd services.
#
# system-manager has no virtualisation.oci-containers or networking.firewall,
# so we create runner services directly using docker/podman run and skip
# firewall configuration (the host firewall must be managed separately).
{ ... }:
{
  flake.modules.systemManager.nix-oci-run-services =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.oci;
      deployLib = import ../../../../lib/deploy.nix { inherit lib; };
      autoStart = deployLib.autoStartContainers cfg.containers;
      backend =
        if cfg.backend == "docker" then "${pkgs.docker}/bin/docker" else "${pkgs.podman}/bin/podman";
    in
    {
      config = lib.mkIf (cfg.enable && autoStart != { }) {
        systemd.services = lib.mapAttrs' (
          name: container:
          lib.nameValuePair "${cfg.backend}-${name}" {
            description = "Run OCI container ${container.imageRef} via ${cfg.backend}";
            after = [
              "network.target"
              "oci-load-${name}.service"
            ];
            requires = [ "oci-load-${name}.service" ];
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              Type = "simple";
              Restart = "on-failure";
              ExecStart = lib.concatStringsSep " " ([ backend ] ++ (deployLib.mkRunArgs name container));
              ExecStop = "${backend} stop ${name}";
              ExecStopPost = "-${backend} rm -f ${name}";
            };
          }
        ) autoStart;
      };
    };
}
