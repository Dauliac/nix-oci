# Home-manager deploy module for soci-snapshotter.
#
# Registers flake.modules.homeManager.soci-snapshotter which provides:
# - soci CLI in user PATH (for building/inspecting SOCI indexes)
#
# The daemon (soci-snapshotter-grpc) requires root and containerd,
# so it is NOT managed by home-manager. Use the NixOS or
# system-manager module to deploy the daemon.
{ ... }:
{
  flake.modules.homeManager.soci-snapshotter =
    { config, lib, ... }:
    let
      cfg = config.services.soci-snapshotter;
    in
    {
      imports = import ./_options;

      config = lib.mkIf cfg.enable {
        home.packages = [ cfg.package ];
      };
    };
}
