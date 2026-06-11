# oci.snapshotter.soci.enable — SOCI v2 lazy-pulling snapshotter.
#
# Configures a containerd proxy snapshotter that generates and serves
# SOCI v2 indexes, enabling lazy image pulls on AWS ECS/Fargate and
# containerd hosts running soci-snapshotter.
#
# Auto-enabled (via mkDefault) when any container has
# performance.turbo.soci.enable = true.
# Requires a non-podman backend (containerd proxy plugin).
{ lib, ... }:
{
  options.soci.enable = lib.mkEnableOption "SOCI v2 lazy-pulling snapshotter (containerd only)";
}
