# System-manager deploy module for soci-snapshotter.
#
# Registers flake.modules.systemManager.soci-snapshotter which provides:
# - systemd service for soci-snapshotter-grpc daemon
# - containerd config drop-in for proxy plugin
# - soci CLI in system PATH
#
# Mirrors nixos.nix but uses system-manager's interface
# (no virtualisation.containerd or boot.kernelModules).
{ ... }:
{
  flake.modules.systemManager.soci-snapshotter =
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
        environment.systemPackages = [ cfg.package ];

        # containerd config drop-in for proxy snapshotter.
        environment.etc = lib.mkIf cfg.containerdIntegration {
          "containerd/config.d/soci-snapshotter.toml" = {
            text = ''
              [proxy_plugins.soci]
                type = "snapshot"
                address = "${cfg.socketPath}"
            '';
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
