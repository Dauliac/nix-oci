# PHP-FPM: healthcheck via FastCGI ping + stop signal.
#
# NixOS uses services.phpfpm.pools.<name>, creating a systemd service
# "phpfpm-<pool>". We match mainService against that pattern to find
# the pool config and derive a healthcheck.
#
# Healthcheck strategy:
# 1. Inject ping.path = "/ping" into the pool settings
# 2. Use cgi-fcgi to send a FastCGI ping request
# 3. PHP-FPM responds with "pong" when healthy
#
# This is the canonical PHP-FPM healthcheck -- it proves the process
# manager is accepting FastCGI connections AND that workers are available.
#
# StopSignal: SIGQUIT -- graceful shutdown, finish serving current requests.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container;

  # Match "phpfpm-<poolName>" from mainService
  poolName =
    let
      prefix = "phpfpm-";
    in
    if cfg.mainService != null && lib.hasPrefix prefix cfg.mainService then
      lib.removePrefix prefix cfg.mainService
    else
      null;

  isPhpFpm = poolName != null && cfg.mainService != null;

  # Read the listen address from pool.socket (read-only, derived from
  # pool.listen). This avoids reading pool.settings which we also write
  # to (that would cause infinite recursion).
  listenAddr =
    if isPhpFpm then
      config.services.phpfpm.pools.${poolName}.socket or "127.0.0.1:9000"
    else
      "127.0.0.1:9000";

  # PHP-FPM may listen on a Unix socket or TCP -- only report TCP ports.
  detectedPort =
    let
      parts = lib.splitString ":" listenAddr;
    in
    if builtins.length parts >= 2 then
      let
        raw = lib.last parts;
      in
      lib.toInt raw
    else
      null;
in
{
  config = lib.mkIf isPhpFpm {
    oci.container._output.detectedPorts = lib.optional (detectedPort != null) detectedPort;
    # Inject ping endpoint into the pool for health checking.
    # PHP-FPM responds with "pong" to FastCGI requests to this path.
    services.phpfpm.pools.${poolName}.settings = {
      "ping.path" = lib.mkDefault "/ping";
      "ping.response" = lib.mkDefault "pong";
    };

    oci.container.healthcheck.command = lib.mkDefault [
      "${pkgs.fcgi}/bin/cgi-fcgi"
      "-bind"
      "-connect"
      listenAddr
    ];
    # SIGQUIT: graceful shutdown -- finish serving current requests.
    oci.container.stopSignal = lib.mkDefault "SIGQUIT";
    oci.container._output.adapterPackages = [ pkgs.fcgi ];
  };
}
