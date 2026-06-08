# Home-manager: forward autoStart containers to services.podman.containers
# and wire load services as dependencies of the generated quadlet services.
{ ... }:
{
  flake.modules.homeManager.nix-oci-podman-containers =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.nix-oci;
      ociLib = cfg.lib;
      autoStartContainers = lib.filterAttrs (_: c: c.autoStart) cfg.containers;
    in
    {
      config = lib.mkIf (cfg.enable && cfg.backend == "podman" && autoStartContainers != { }) {
        services.podman = {
          enable = true;
          containers = lib.mapAttrs (_name: container: {
            image = container.imageRef;
          }) autoStartContainers;
        };

        systemd.user.services = lib.mapAttrs' (
          name: _container:
          let
            loadServiceName = ociLib.mkLoadServiceName name;
          in
          lib.nameValuePair "podman-${name}" {
            Unit = {
              After = [ "${loadServiceName}.service" ];
              Requires = [ "${loadServiceName}.service" ];
            };
          }
        ) autoStartContainers;
      };
    };
}
