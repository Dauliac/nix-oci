# Postfix: foreground mode + healthcheck via postfix status + stop signal.
#
# NixOS postfix uses Type=forking with "postfix start". Postfix 3.4+
# supports "postfix start-fg" which keeps the master in the foreground.
#
# Healthcheck: "postfix status" checks if the mail system is running.
# This is the canonical Postfix health check -- it queries the master
# process via the Postfix command interface.
#
# StopSignal: SIGTERM -- postfix master exits cleanly on SIGTERM.
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container;
  isPostfix = cfg.mainService == "postfix";
  postfixPkg = config.services.postfix.package;
in
{
  config = lib.mkIf isPostfix {
    oci.container._output.detectedPorts = [ 25 ];
    systemd.services.postfix.serviceConfig = {
      Type = lib.mkForce "simple";
      ExecStart = lib.mkForce "${postfixPkg}/bin/postfix start-fg";
    };

    oci.container.healthcheck.command = lib.mkDefault [
      "${postfixPkg}/bin/postfix"
      "status"
    ];
    oci.container.stopSignal = lib.mkDefault "SIGTERM";
  };
}
