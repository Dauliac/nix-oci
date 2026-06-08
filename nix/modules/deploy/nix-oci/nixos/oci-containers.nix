# NixOS: forward autoStart containers to virtualisation.oci-containers
# and wire load services as dependencies of the generated run services.
{ ... }:
{
  flake.modules.nixos.nix-oci-oci-containers =
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
      config = lib.mkIf (cfg.enable && autoStartContainers != { }) {
        virtualisation.oci-containers = {
          backend = cfg.backend;
          containers = lib.mapAttrs (_name: container: {
            image = container.imageRef;
            pull = "never";
          }) autoStartContainers;
        };

        systemd.services = lib.mapAttrs' (
          name: container:
          let
            serviceName =
              config.virtualisation.oci-containers.containers.${name}.serviceName or "${cfg.backend}-${name}";
            loadServiceName = ociLib.mkLoadServiceName name;
          in
          lib.nameValuePair serviceName {
            after = [ "${loadServiceName}.service" ];
            requires = [ "${loadServiceName}.service" ];
          }
        ) autoStartContainers;
      };
    };
}
