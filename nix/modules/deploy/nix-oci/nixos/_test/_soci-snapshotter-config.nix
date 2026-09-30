# NixOS config: SOCI snapshotter bundle for integration testing.
#
# Activates when services.soci-snapshotter.enable is true.
# Orchestrates docker + registry + insecure registry config.
#
# IMPORTANT: this module deliberately does NOT define `oci.backend`.
# The cycle root
#   oci.snapshotter -> oci.backend -> _soci-snapshotter-config -> ...
#   ... services.soci-snapshotter.enable -> snap.soci.enable -> oci.snapshotter
# is only closed when `oci.backend` reads back into this module. Test
# harnesses that need containerd must set the backend explicitly (e.g.
# `test.oci._vmBackend = "docker"` in test-vm.nix), NOT rely on this
# module to flip it. Same for oci.registry.enable / port: setting them
# here reintroduces the same class of cycle via the auto-enable branch
# in snapshotter.nix that also touches oci.registry.
{
  config,
  lib,
  ...
}:
let
  socisOn = config.services.soci-snapshotter.enable or false;
in
{
  virtualisation.docker.enable = lib.mkIf socisOn (lib.mkDefault true);
  virtualisation.containerd.settings = lib.mkIf socisOn {
    plugins."io.containerd.grpc.v1.cri".registry.configs = {
      "localhost:${toString config.services.dockerRegistry.port}" = {
        tls.insecure_skip_verify = true;
      };
    };
  };
}
