# vsftpd: foreground mode + stop signal.
#
# NixOS vsftpd uses Type=forking with background=YES in its config.
# Setting background=NO keeps the process in the foreground.
#
# No healthcheck injection — vsftpd doesn't have a built-in status
# command, and FTP connection checks require protocol-level interaction.
# Users should set healthcheck.command explicitly if needed.
#
# StopSignal: SIGTERM — vsftpd exits cleanly on SIGTERM.
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container;
  isVsftpd = cfg.mainService == "vsftpd";
in
{
  config = lib.mkIf isVsftpd {
    services.vsftpd.extraConfig = lib.mkDefault "background=NO";
    oci.container.stopSignal = lib.mkDefault "SIGTERM";
  };
}
