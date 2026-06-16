# NixOS config: SOCI snapshotter bundle for integration testing.
#
# Activates when services.soci-snapshotter.enable is true.
# Orchestrates docker/containerd + registry + insecure registry config.
{
  config,
  lib,
  ...
}:
lib.mkIf (config.services.soci-snapshotter.enable or false) {
  oci.backend = lib.mkDefault "docker";
  oci.registry = {
    enable = lib.mkDefault true;
    port = lib.mkDefault config.services.dockerRegistry.port;
  };
  virtualisation.docker.enable = lib.mkDefault true;
  virtualisation.containerd.settings = {
    plugins."io.containerd.grpc.v1.cri".registry.configs = {
      "localhost:${toString config.services.dockerRegistry.port}" = {
        tls.insecure_skip_verify = true;
      };
    };
  };
}
