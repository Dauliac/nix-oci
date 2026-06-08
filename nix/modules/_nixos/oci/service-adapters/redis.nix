# Redis: auto-derive healthcheck + stop signal from NixOS module config.
#
# NixOS uses services.redis.servers.<name>, creating a systemd service
# "redis-<name>". This adapter resolves logical names:
#   mainService = "redis"         → systemd "redis-default" (first enabled server)
#   mainService = "redis-myname"  → systemd "redis-myname"
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

  # Resolve logical name → server name + systemd unit name
  resolved =
    if mainSvc == "redis" then
      # Bare "redis": find the first enabled server (usually "default")
      let
        servers = config.services.redis.servers or { };
        enabledNames = lib.filter (n: servers.${n}.enable or false) (lib.attrNames servers);
        name = if enabledNames != [ ] then builtins.head (lib.sort lib.lessThan enabledNames) else null;
      in
      if name != null then
        {
          serverName = name;
          systemdName = "redis-${name}";
          serverCfg = servers.${name};
        }
      else
        null
    else if lib.hasPrefix "redis-" mainSvc then
      # Explicit "redis-<name>": use directly
      let
        name = lib.removePrefix "redis-" mainSvc;
        servers = config.services.redis.servers or { };
      in
      if servers ? ${name} then
        {
          serverName = name;
          systemdName = mainSvc;
          serverCfg = servers.${name};
        }
      else
        null
    else
      null;

  isRedis = resolved != null;
  serverCfg = if isRedis then resolved.serverCfg else null;
  port = if isRedis then toString (serverCfg.port or 6379) else "6379";
  bind = if isRedis then serverCfg.bind or "127.0.0.1" else "127.0.0.1";
  bindAddr = builtins.head (lib.splitString " " bind);
in
{
  config = lib.mkIf (isRedis && cfg.mainService != null) {
    # Resolve logical → systemd service name
    oci.container.resolvedSystemdServiceName = lib.mkDefault resolved.systemdName;
    # Resolve package (lives under servers.<name>, not services.redis)
    oci.container.resolvedServicePackage = lib.mkDefault (
      config.services.redis.package or serverCfg.package or null
    );

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
