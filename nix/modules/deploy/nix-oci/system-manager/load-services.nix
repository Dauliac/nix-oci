# System-manager: systemd load services using nix2container passthru copy scripts.
#
# system-manager supports systemd.services natively and auto-rewrites
# multi-user.target → system-manager.target.
{ ... }:
{
  flake.modules.systemManager.nix-oci-load-services =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.oci;
      deployLib = import ../../../../lib/deploy.nix { inherit lib; };
    in
    {
      config = lib.mkIf cfg.enable {
        systemd.services = lib.mapAttrs' (
          name: container:
          let
            script = deployLib.copyScript {
              backend = cfg.backend;
              inherit container;
            };
          in
          lib.nameValuePair "oci-load-${name}" {
            description = "Load OCI image ${container.imageRef} into ${cfg.backend}";
            after = [ "network.target" ] ++ lib.optional (cfg.backend == "docker") "docker.service";
            requires = lib.optional (cfg.backend == "docker") "docker.service";
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${script}/bin/${script.name}";
            };
          }
        ) cfg.containers;
      };
    };
}
