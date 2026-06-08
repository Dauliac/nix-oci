# nginx: run in foreground (daemon off)
#
# NixOS nginx uses Type=forking with a PIDFile. In containers there is
# no init system, so we inject "daemon off;" to keep the master process
# in the foreground.
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container;
in
{
  config.services.nginx.appendConfig = lib.mkIf (cfg.mainService == "nginx") (
    lib.mkDefault "daemon off;"
  );
}
