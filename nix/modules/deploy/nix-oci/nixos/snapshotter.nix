# NixOS: configure containerd proxy snapshotters and Podman storage
# for lazy-pulling support.
#
# Uses the shared _snapshotter/lib.nix for config fragment generation
# and _snapshotter/assertions.nix for backend compatibility checks.
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
      snapshotterLib = import ../options/_snapshotter/lib.nix { inherit lib; };
      snapshotterAssertions = import ../options/_snapshotter/assertions.nix { inherit lib; };
      anySnapshotterEnabled = snap.soci.enable || snap.stargz.enable || snap.zstdChunked.enable;
    in
    {
      config = lib.mkIf (cfg.enable && anySnapshotterEnabled) {
        assertions = snapshotterAssertions.mkAssertions cfg;

        # containerd proxy snapshotter plugins (SOCI or stargz).
        virtualisation.containerd.settings = lib.mkIf (snap.soci.enable || snap.stargz.enable) (
          snapshotterLib.mkContainerdConfig snap
        );

        # Snapshotter gRPC daemon services.
        systemd.services =
          (snapshotterLib.mkSociService { inherit snap pkgs; })
          // (snapshotterLib.mkStargzService { inherit snap pkgs; });

        # Podman zstd:chunked via storage.conf drop-in.
        environment.etc = lib.mkIf snap.zstdChunked.enable {
          "containers/storage.conf.d/zstd-chunked.conf" = {
            text = snapshotterLib.mkStorageConf snap;
          };
        };
      };
    };
}
