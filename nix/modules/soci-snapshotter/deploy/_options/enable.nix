# services.soci-snapshotter.enable — enable the SOCI snapshotter daemon.
{ lib, ... }:
{
  options.services.soci-snapshotter.enable = lib.mkEnableOption "SOCI v2 lazy-pulling snapshotter (containerd proxy plugin)";
}
