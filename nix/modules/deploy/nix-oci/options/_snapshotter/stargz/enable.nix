# oci.snapshotter.stargz.enable — eStargz lazy-pulling snapshotter.
#
# Configures a containerd proxy snapshotter for eStargz images,
# enabling lazy pulls on containerd hosts with stargz-snapshotter.
#
# Requires a non-podman backend (containerd proxy plugin).
{ lib, ... }:
{
  options.stargz.enable = lib.mkEnableOption "eStargz lazy-pulling snapshotter (containerd only)";
}
