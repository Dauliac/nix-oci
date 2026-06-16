# NixOS: systemd load services using nix2container passthru copy scripts.
#
# Three loading strategies:
#   1. Registry push (oci.registry.enable) — copyToRegistry to localhost registry.
#      Enables SOCI lazy pull and layer dedup via containerd snapshotters.
#   2. Docker daemon — copyToDockerDaemon (direct load, no snapshotter benefit).
#   3. Podman — copyToPodman (direct load to containers-storage).
{ ... }:
{
  flake.modules.nixos.nix-oci-load-services =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.oci;
      reg = cfg.registry;
      deployLib = import ../../../../lib/deploy.nix { inherit lib; };
      useRegistry = reg.enable;
    in
    {
      config = lib.mkIf cfg.enable {
        systemd.services = lib.mapAttrs' (
          name: container:
          let
            registry = if useRegistry then reg else null;
            script = deployLib.copyScript {
              backend = cfg.backend;
              inherit container registry;
            };
            registryRef = deployLib.registryImageRef {
              inherit registry container;
            };
            # For registry push, override the destination to localhost:port/name:tag
            execStart =
              if useRegistry then
                let
                  regUrl = "docker://${registryRef}";
                in
                "${script}/bin/${script.name} --dest-tls-verify=false ${regUrl}"
              else
                "${script}/bin/${script.name}";
          in
          lib.nameValuePair "oci-load-${name}" {
            description =
              if useRegistry then
                "Push OCI image ${container.imageRef} to registry ${reg.host}:${toString reg.port}"
              else
                "Load OCI image ${container.imageRef} into ${cfg.backend}";
            after =
              [ "network.target" ]
              ++ lib.optional (cfg.backend == "docker" && !useRegistry) "docker.service"
              ++ lib.optional useRegistry "docker-registry.service";
            requires =
              lib.optional (cfg.backend == "docker" && !useRegistry) "docker.service"
              ++ lib.optional useRegistry "docker-registry.service";
            wantedBy = [ "multi-user.target" ];

            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = execStart;
            };
          }
        ) cfg.containers;
      };
    };
}
