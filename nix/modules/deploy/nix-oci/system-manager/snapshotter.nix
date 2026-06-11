# System-manager: configure containerd proxy snapshotters and Podman
# storage for lazy-pulling support.
#
# Mirrors nixos/snapshotter.nix but uses system-manager's systemd
# service interface and file management (no virtualisation.containerd
# or environment.etc — we write services and config files directly).
{ ... }:
{
  flake.modules.systemManager.nix-oci-snapshotter-config =
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

        # Snapshotter gRPC daemon services.
        systemd.services =
          (snapshotterLib.mkSociService { inherit snap pkgs; })
          // (snapshotterLib.mkStargzService { inherit snap pkgs; });

        # containerd config drop-in for proxy snapshotters.
        # system-manager manages files via environment.etc when available,
        # otherwise we rely on the service writing its own config.
        environment.etc = lib.mkMerge [
          (lib.mkIf (snap.soci.enable || snap.stargz.enable) {
            "containerd/config.d/snapshotter.toml" = {
              text =
                let
                  cfg' = snapshotterLib.mkContainerdConfig snap;
                  pluginName = if snap.soci.enable then "soci" else "stargz";
                  address = cfg'.proxy_plugins.${pluginName}.address;
                in
                ''
                  [proxy_plugins.${pluginName}]
                    type = "snapshot"
                    address = "${address}"
                '';
            };
          })
          (lib.mkIf snap.zstdChunked.enable {
            "containers/storage.conf.d/zstd-chunked.conf" = {
              text = snapshotterLib.mkStorageConf snap;
            };
          })
        ];
      };
    };
}
