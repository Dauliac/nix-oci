# vsftpd: run in foreground
#
# NixOS vsftpd uses Type=forking with background=YES in its config.
# Setting background=NO keeps the process in the foreground.
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container;
in
{
  config.services.vsftpd.extraConfig = lib.mkIf (cfg.mainService == "vsftpd") (
    lib.mkDefault "background=NO"
  );
}
