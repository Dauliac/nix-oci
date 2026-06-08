# NixOS: systemd load services using nix2container passthru copy scripts.
{ ... }:
{
  flake.modules.nixos.nix-oci-load-services =
    { config, lib, ... }:
    let
      cfg = config.oci;
      copyScript =
        container:
        if cfg.backend == "docker" then
          container.image.copyToDockerDaemon
        else
          container.image.copyToPodman;
    in
    {
      config = lib.mkIf cfg.enable {
        systemd.services = lib.mapAttrs' (
          name: container:
          let
            script = copyScript container;
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
