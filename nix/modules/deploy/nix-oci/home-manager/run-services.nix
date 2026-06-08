# Home-manager: forward autoStart containers to services.podman.containers.
# Loader dependency is wired via the podman quadlet's extraConfig.Unit
# (NOT via systemd.user.services, which would conflict with the quadlet file).
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
            name: container:
            {
              image = container.imageRef;
              extraConfig = {
                Unit = {
                  After = [ "oci-load-${name}.service" ];
                  Requires = [ "oci-load-${name}.service" ];
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
          ) autoStart;
        };
      };
    };
}
