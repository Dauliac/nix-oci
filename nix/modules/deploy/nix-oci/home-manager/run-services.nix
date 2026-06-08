# Home-manager: forward autoStart containers to services.podman.containers
# and wire loader as dependency of the runner.
{ ... }:
{
  flake.modules.homeManager.nix-oci-run-services =
    { config, lib, ... }:
    let
      cfg = config.oci;
      autoStart = lib.filterAttrs (_: c: c.autoStart) cfg.containers;
    in
    {
      config = lib.mkIf (cfg.enable && cfg.backend == "podman" && autoStart != { }) {
        services.podman = {
          enable = true;
          containers = lib.mapAttrs (
            _name: container:
            {
              image = container.imageRef;
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
        systemd.user.services = lib.mapAttrs' (
          name: _:
          lib.nameValuePair "podman-${name}" {
            Unit = {
              After = [ "oci-load-${name}.service" ];
              Requires = [ "oci-load-${name}.service" ];
            };
          }
        ) autoStart;
      };
    };
}
