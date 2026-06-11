# Pure functions to generate intermediate configuration fragments
# for lazy-pulling snapshotters.
#
# Each function returns a data structure that platform-specific modules
# (nixos/snapshotter.nix, system-manager/snapshotter.nix) translate
# into native NixOS or system-manager configuration.
{ lib }:
{
  # Generate containerd config.toml fragments for proxy snapshotters.
  # Returns an attrset suitable for merging into
  # virtualisation.containerd.settings or a raw TOML generator.
  mkContainerdConfig =
    snap:
    let
      sociPlugin = lib.optionalAttrs snap.soci.enable {
        proxy_plugins.soci = {
          type = "snapshot";
          address = snap.soci.socketPath;
        };
      };
      stargzPlugin = lib.optionalAttrs snap.stargz.enable {
        proxy_plugins.stargz = {
          type = "snapshot";
          address = snap.stargz.socketPath;
        };
      };
    in
    sociPlugin // stargzPlugin;

  # Generate the systemd service definition for the SOCI snapshotter daemon.
  # Returns an attrset of { serviceName = serviceConfig; }.
  mkSociService =
    {
      snap,
      pkgs,
    }:
    lib.optionalAttrs snap.soci.enable {
      soci-snapshotter = {
        description = "SOCI Snapshotter gRPC service";
        after = [ "containerd.service" ];
        requires = [ "containerd.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = 5;
          ExecStart = "${pkgs.soci-snapshotter}/bin/soci-snapshotter-grpc --address ${snap.soci.socketPath}";
          RuntimeDirectory = "soci-snapshotter-grpc";
        };
      };
    };

  # Generate the systemd service definition for the stargz snapshotter daemon.
  mkStargzService =
    {
      snap,
      pkgs,
    }:
    lib.optionalAttrs snap.stargz.enable {
      stargz-snapshotter = {
        description = "Stargz Snapshotter gRPC service";
        after = [ "containerd.service" ];
        requires = [ "containerd.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "simple";
          Restart = "always";
          RestartSec = 5;
          ExecStart = "${pkgs.stargz-snapshotter}/bin/containerd-stargz-grpc --address ${snap.stargz.socketPath}";
          RuntimeDirectory = "containerd-stargz-grpc";
        };
      };
    };

  # Generate containers/storage.conf overrides for zstd:chunked (Podman).
  # Returns the storage.conf content fragment as a string.
  mkStorageConf =
    snap:
    lib.optionalString snap.zstdChunked.enable ''
      [storage.options.pull_options]
      enable_partial_images = "true"
      use_hard_links = "false"
      ostree_repos = ""
    '';
}
