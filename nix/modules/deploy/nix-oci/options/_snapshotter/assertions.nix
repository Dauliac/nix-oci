# Shared assertions for snapshotter ↔ backend compatibility.
#
# Consumed by the coordinator (snapshotter.nix) and evaluated in the
# NixOS / system-manager module context where `config.oci` is available.
{ lib }:
let
  mkAssertions =
    cfg:
    let
      snap = cfg.snapshotter;
      backend = cfg.backend;
    in
    [
      {
        assertion = snap.soci.enable -> backend != "podman";
        message = ''
          oci.snapshotter.soci requires containerd (proxy snapshotter).
          The current backend is "podman". Either switch to docker
          (which uses containerd internally) or disable SOCI.
        '';
      }
      {
        assertion = snap.stargz.enable -> backend != "podman";
        message = ''
          oci.snapshotter.stargz requires containerd (proxy snapshotter).
          The current backend is "podman". Either switch to docker
          (which uses containerd internally) or disable stargz.
        '';
      }
      {
        assertion = snap.zstdChunked.enable -> backend == "podman";
        message = ''
          oci.snapshotter.zstdChunked is a Podman/CRI-O native feature
          (containers/storage). The current backend is "${backend}".
          Switch to podman or disable zstd:chunked.
        '';
      }
      {
        assertion = !(snap.soci.enable && snap.stargz.enable);
        message = ''
          SOCI and stargz snapshotters are mutually exclusive.
          Only one containerd proxy snapshotter can be the default.
          Choose either oci.snapshotter.soci or oci.snapshotter.stargz.
        '';
      }
      {
        assertion = !(snap.zstdChunked.enable && (snap.soci.enable || snap.stargz.enable));
        message = ''
          zstd:chunked (Podman) and containerd snapshotters (SOCI/stargz)
          target different runtimes and cannot be enabled simultaneously.
        '';
      }
    ];
in
{
  inherit mkAssertions;
}
