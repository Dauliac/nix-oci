# NixOS: forward autoStart containers to virtualisation.oci-containers,
# wire loader as dependency of the runner, and open firewall for exposed ports.
{ ... }:
{
  flake.modules.nixos.nix-oci-run-services =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.oci;
      autoStart = lib.filterAttrs (_: c: c.autoStart) cfg.containers;

      # Extract all host ports across all autoStart containers for the firewall.
      allHostPorts = lib.concatMap (
        container:
        map (
          portSpec:
          let
            raw = builtins.head (lib.splitString ":" portSpec);
            clean = builtins.head (lib.splitString "/" raw);
          in
          lib.toInt clean
        ) container.ports
      ) (lib.attrValues autoStart);
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

        # Auto-open firewall for exposed host ports
        networking.firewall.allowedTCPPorts = allHostPorts;

        # Runner depends on loader
        systemd.services = lib.mapAttrs' (
          name: _:
          let
            serviceName =
              config.virtualisation.oci-containers.containers.${name}.serviceName or "${cfg.backend}-${name}";
          in
          lib.nameValuePair serviceName {
            after = [ "oci-load-${name}.service" ];
            requires = [ "oci-load-${name}.service" ];
          }
        ) autoStart;
      };
    };
}
