# Redis: auto-derive healthcheck + stop signal from NixOS module config.
#
# NixOS uses services.redis.servers.<name>, creating a systemd service
# "redis-<name>". We match mainService against that pattern to find the
# right server config and derive a redis-cli ping healthcheck.
#
# No foreground adapter needed — NixOS redis runs with daemonize=no.
# StopSignal: SIGTERM — Redis saves the dataset and exits gracefully.
{
  config,
  lib,
  ...
}:
let
  cfg = config.oci.container;

  mainSvc = if cfg.mainService != null then cfg.mainService else "";

  serverName =
    let
      prefix = "redis-";
    in
    if lib.hasPrefix prefix mainSvc then lib.removePrefix prefix mainSvc else null;

  serverCfg =
    if serverName != null then config.services.redis.servers.${serverName} or null else null;

  port = toString (serverCfg.port or 6379);
  bind = serverCfg.bind or "127.0.0.1";
  bindAddr = builtins.head (lib.splitString " " bind);
in
{
  config = lib.mkIf (serverCfg != null && cfg.mainService != null) {
    oci.container.healthcheck.command = lib.mkDefault [
      "${config.services.redis.package or serverCfg.package}/bin/redis-cli"
      "-h"
      bindAddr
      "-p"
      port
      "ping"
    ];
    # SIGTERM: Redis saves dataset (if configured) and exits gracefully.
    oci.container.stopSignal = lib.mkDefault "SIGTERM";
  };
}
