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

  # Matches the "ping.path" default injected below. Not read back from
  # pool.settings: this module also writes that key, and pool.settings
  # is merged as a whole, so reading it here risks the same infinite
  # recursion the `listenAddr`/`socket` comment above warns about.
  pingPath = "/ping";

  # PHP-FPM may listen on a Unix socket or TCP -- only report TCP ports.
  addrParts = lib.splitString ":" listenAddr;
  isTcp = builtins.length addrParts >= 2;
  detectedPort = if isTcp then lib.toInt (lib.last addrParts) else null;

  # A wildcard bind host ("0.0.0.0"/"*"/"::") is not a usable connect
  # target for cgi-fcgi (see the dnsmasq adapter for the same issue);
  # query loopback instead, which a wildcard-bound pool also answers on.
  healthConnectAddr =
    if
      isTcp
      && builtins.elem (lib.head addrParts) [
        "0.0.0.0"
        "*"
        "::"
      ]
    then
      "127.0.0.1:${toString detectedPort}"
    else
      listenAddr;
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

    # cgi-fcgi forwards its entire process environment as FastCGI params
    # (it has no notion of "just these CGI vars"). Two consequences:
    #   1. Without SCRIPT_NAME/SCRIPT_FILENAME/REQUEST_METHOD set, PHP-FPM
    #      never sees a request matching ping.path, so the check can't
    #      actually prove the pool is serving requests.
    #   2. podman execs --health-cmd with the container's full (and often
    #      sizeable) environment inherited. The bundled fcgi library is old
    #      enough that forwarding a large/unclean environ as FCGI_PARAMS
    #      makes FPM hang up mid-handshake (connect() succeeds, then the
    #      first write gets SIGPIPE/ECONNRESET) -- reproduced locally: the
    #      exact same cgi-fcgi invocation returns pong under a minimal env
    #      and fails under a realistic container-sized one.
    # `env -i` resets to only the three CGI vars the ping handler needs,
    # fixing both at once.
    oci.container.healthcheck.command = lib.mkDefault [
      "${pkgs.coreutils}/bin/env"
      "-i"
      "SCRIPT_NAME=${pingPath}"
      "SCRIPT_FILENAME=${pingPath}"
      "REQUEST_METHOD=GET"
      "${pkgs.fcgi}/bin/cgi-fcgi"
      "-bind"
      "-connect"
      healthConnectAddr
    ];
    # SIGQUIT: graceful shutdown -- finish serving current requests.
    oci.container.stopSignal = lib.mkDefault "SIGQUIT";
    oci.container.extraPackages = [
      pkgs.fcgi
      pkgs.coreutils
    ];
  };
}
