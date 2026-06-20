# NixOS deploy module for soci-snapshotter.
#
# Registers flake.modules.nixos.soci-snapshotter which provides:
# - systemd service for soci-snapshotter-grpc daemon
# - containerd proxy plugin configuration
# - FUSE kernel module + userspace tools
# - soci CLI in system PATH
#
# Standalone and extractable — no dependency on nix-oci internals.
{ ... }:
{
  flake.modules.nixos.soci-snapshotter =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.services.soci-snapshotter;
    in
    {
      imports = import ./_options;

      config = lib.mkIf cfg.enable {
        # FUSE is required for lazy-mounting layers.
        boot.kernelModules = [ "fuse" ];

        # soci CLI + fuse3 in system PATH.
        environment.systemPackages = [
          cfg.package
        ];

        # containerd proxy plugin registration.
        virtualisation.containerd.settings = lib.mkIf cfg.containerdIntegration {
          proxy_plugins.soci = {
            type = "snapshot";
            address = cfg.socketPath;
          };
        };

        # soci-snapshotter-grpc systemd service.
        systemd.services.soci-snapshotter = {
          description = "SOCI Snapshotter gRPC service";
          after = [ "containerd.service" ];
          requires = [ "containerd.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            Restart = "always";
            RestartSec = 5;
            ExecStart = "${cfg.package}/bin/soci-snapshotter-grpc --address ${cfg.socketPath}";
            RuntimeDirectory = "soci-snapshotter-grpc";
          };
        };
      };
    };
}
