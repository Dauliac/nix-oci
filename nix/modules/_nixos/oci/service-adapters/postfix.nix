# Postfix: run in foreground
#
# NixOS postfix uses Type=forking with "postfix start" which spawns
# the master daemon and exits. Postfix 3.4+ supports "postfix start-fg"
# which keeps the master process in the foreground.
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container;
in
{
  config = lib.mkIf (cfg.mainService == "postfix") {
    systemd.services.postfix.serviceConfig = {
      Type = lib.mkForce "simple";
      ExecStart = lib.mkForce "${config.services.postfix.package}/bin/postfix start-fg";
    };
  };
}
