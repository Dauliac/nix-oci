# NixOS: forward autoStart containers to virtualisation.oci-containers
# and wire loader as dependency of the runner.
{ ... }:
{
  flake.modules.nixos.nix-oci-run-services =
    { config, lib, ... }:
    let
      cfg = config.oci;
      autoStart = lib.filterAttrs (_: c: c.autoStart) cfg.containers;
    in
    {
      config = lib.mkIf (cfg.enable && autoStart != { }) {
        virtualisation.oci-containers = {
          backend = cfg.backend;
          containers = lib.mapAttrs (
            _name: container:
            {
              image = container.imageRef;
              pull = "never";
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
          ) autoStart;
        };

        # Runner depends on loader
        systemd.services = lib.mapAttrs' (
          name: _:
          let
            serviceName =
              config.virtualisation.oci-containers.containers.${name}.serviceName
                or "${cfg.backend}-${name}";
          in
          lib.nameValuePair serviceName {
            after = [ "oci-load-${name}.service" ];
            requires = [ "oci-load-${name}.service" ];
          }
        ) autoStart;
      };
    };
}
