# Home-manager: systemd user load services using nix2container passthru copy scripts.
#
# Rootless podman needs setuid newuidmap/newgidmap from NixOS wrappers.
{ ... }:
{
  flake.modules.homeManager.nix-oci-load-services =
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
        systemd.user.services = lib.mapAttrs' (
          name: container:
          let
            script = deployLib.copyScript {
              backend = cfg.backend;
              inherit container;
            };
          in
          lib.nameValuePair "oci-load-${name}" {
            Unit.Description = "Load OCI image ${container.imageRef} into ${cfg.backend}";
            Install.WantedBy = [ "default.target" ];
            Service = {
              Type = "oneshot";
              RemainAfterExit = true;
              Environment = [ "PATH=/run/wrappers/bin:/run/current-system/sw/bin" ];
              ExecStart = "${script}/bin/${script.name}";
            };
          }
        ) cfg.containers;
      };
    };
}
