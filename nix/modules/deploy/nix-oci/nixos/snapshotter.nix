# NixOS: configure containerd proxy snapshotters and Podman storage
# for lazy-pulling support.
#
# SOCI is delegated to the standalone services.soci-snapshotter module.
# Stargz and zstd:chunked remain in _snapshotter/_lib.nix.
#
# Auto-enable: when any container has performance.turbo.soci = true
# and the backend is containerd-based ("docker"), SOCI is auto-enabled
# via mkDefault so users can still override.
{ ... }:
{
  flake.modules.nixos.nix-oci-snapshotter-config =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.oci;
      snap = cfg.snapshotter;
      snapshotterLib = import ../options/_snapshotter/_lib.nix { inherit lib; };
      snapshotterAssertions = import ../options/_snapshotter/_assertions.nix { inherit lib; };
      anySnapshotterEnabled = snap.soci.enable || snap.stargz.enable || snap.zstdChunked.enable;

      # Detect if any container requests turbo SOCI indexes.
      anyContainerWantsSoci = builtins.any (
        c: (c.performance.turbo.enable or false) && (c.performance.turbo.soci or false)
      ) (builtins.attrValues cfg.containers);
      isContainerdBackend = cfg.backend == "docker";
    in
    {
      config = lib.mkMerge [
        # Auto-enable SOCI + registry when turbo.soci is used with a containerd backend.
        # Registry push is required for SOCI lazy pull (containerd pulls from registry).
        (lib.mkIf (cfg.enable && anyContainerWantsSoci && isContainerdBackend) {
          oci.snapshotter.soci.enable = lib.mkDefault true;
          oci.registry.enable = lib.mkDefault true;
        })

        # Apply snapshotter configuration when any snapshotter is enabled.
        (lib.mkIf (cfg.enable && anySnapshotterEnabled) {
          assertions = snapshotterAssertions.mkAssertions cfg ++ [
            {
              assertion = snap.soci.enable -> cfg.registry.enable;
              message = ''
                oci.snapshotter.soci requires oci.registry.enable = true.
                SOCI lazy pulling only works when images are pushed to an OCI
                registry — containerd pulls from the registry using the SOCI
                snapshotter. Direct loading (copyToDockerDaemon) bypasses the
                snapshotter entirely.
              '';
            }
          ];

          # SOCI: bridge to standalone services.soci-snapshotter module.
          services.soci-snapshotter = lib.mkIf snap.soci.enable {
            enable = true;
            socketPath = snap.soci.socketPath;
            spanSize = snap.soci.spanSize;
          };

          # stargz: containerd proxy plugin (not yet extracted to standalone).
          virtualisation.containerd.settings = lib.mkIf snap.stargz.enable (
            snapshotterLib.mkContainerdConfig snap
          );

          # stargz: gRPC daemon service.
          systemd.services = snapshotterLib.mkStargzService { inherit snap pkgs; };

          # Podman zstd:chunked via storage.conf drop-in.
          environment.etc = lib.mkIf snap.zstdChunked.enable {
            "containers/storage.conf.d/zstd-chunked.conf" = {
              text = snapshotterLib.mkStorageConf snap;
            };
          };
        })
      ];
    };
}
