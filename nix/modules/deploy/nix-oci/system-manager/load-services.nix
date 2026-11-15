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
        # `oci.registry` is registered for systemManager in
        # options/registry.nix and imported into this composition by
        # compose.nix, but neither this loader nor system-manager's
        # run-services has a registry branch. Enabling it fell through
        # to a direct backend load, silently losing the SOCI lazy pull
        # that is the stated reason the registry path exists. Say so
        # rather than quietly doing the wrong thing.
        assertions = [
          {
            assertion = !(cfg.registry.enable or false);
            message = ''
              oci.registry.enable is not implemented for the system-manager deploy
              target: images are loaded directly into ${cfg.backend} and the local
              registry is never used, so SOCI lazy pull would silently not apply.

              Either set oci.registry.enable = false here, or deploy these
              containers through the NixOS target, which implements the registry
              push path.
            '';
          }
        ];

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
