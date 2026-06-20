# nginx: foreground mode + injected health endpoint + stop signal.
#
# NixOS nginx already generates "daemon off;" in its config, keeping
# the master process in the foreground (required for containers).
#
# Healthcheck strategy (priority order):
# 1. User-defined health endpoint (scan for /health, /healthz, /nginx_status, stub_status)
# 2. Inject internal stub_status server on 127.0.0.1:10246 (localhost-only,
#    no access logs, zero interference with user vhosts)
#
# stub_status proves nginx is genuinely processing requests -- not just
# that the process is alive. It also provides connection metrics.
#
# StopSignal: SIGQUIT for graceful worker shutdown (finish current requests).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container;
  nginxCfg = config.services.nginx;

  isNginx = cfg.mainService == "nginx";

  vhostList = lib.attrValues nginxCfg.virtualHosts;

  # Known health endpoint paths, in priority order
  healthPaths = [
    "/health"
    "/healthz"
    "/ready"
    "/nginx_status"
    "/status"
  ];

  allLocations = lib.concatMap (
    vh: map (path: { inherit path vh; }) (lib.attrNames (vh.locations or { }))
  ) vhostList;

  healthLocation = lib.findFirst (loc: lib.elem loc.path healthPaths) null allLocations;

  hasStubStatus = lib.any (
    vh:
    lib.any (loc: lib.hasInfix "stub_status" (loc.extraConfig or "")) (
      lib.attrValues (vh.locations or { })
    )
  ) vhostList;

  # Does the user already have a usable health endpoint?
  hasUserHealthEndpoint = hasStubStatus || healthLocation != null;

  # Internal health server port -- high port, localhost-only, works with non-root
  internalHealthPort = 10246;

  # Determine port and protocol for user-defined endpoints
  firstVhost = if vhostList != [ ] then builtins.head vhostList else null;
  listenDirs = firstVhost.listen or [ ];
  firstListen = if listenDirs != [ ] then builtins.head listenDirs else null;

  port = if firstListen != null then firstListen.port or 80 else nginxCfg.defaultHTTPListenPort or 80;

  ssl =
    if firstListen != null then
      firstListen.ssl or false
    else if firstVhost != null then
      (firstVhost.onlySSL or false) || (firstVhost.forceSSL or false)
    else
      false;

  protocol = if ssl then "https" else "http";

  # Health path for user-defined endpoints
  userHealthPath =
    if hasStubStatus then
      "/nginx_status"
    else if healthLocation != null then
      healthLocation.path
    else
      "/";

  # Final healthcheck URL: use user endpoint if available, otherwise internal
  healthUrl =
    if hasUserHealthEndpoint then
      "${protocol}://localhost:${toString port}${userHealthPath}"
    else
      "http://127.0.0.1:${toString internalHealthPort}/";

  healthCmd = [
    "${pkgs.curl}/bin/curl"
    "-f"
    "--max-time"
    "5"
  ]
  ++ lib.optionals (hasUserHealthEndpoint && ssl) [ "-k" ]
  ++ [ healthUrl ];
in
{
  config = lib.mkIf isNginx {
    # NixOS nginx module already sets "daemon off;" in the generated config.
    # Do NOT append it again — duplicate daemon directives cause nginx to fail.

    # Inject internal stub_status server when user has no health endpoint.
    # Uses appendHttpConfig to add a raw server{} block inside the http{}
    # context -- doesn't pollute virtualHosts or interfere with user config.
    services.nginx.appendHttpConfig = lib.mkIf (!hasUserHealthEndpoint) ''
      server {
          listen 127.0.0.1:${toString internalHealthPort};
          server_name _;
          location / {
              stub_status on;
              access_log off;
          }
      }
    '';

    oci.container._output.detectedPorts = [
      port
    ]
    ++ lib.optional (!hasUserHealthEndpoint) internalHealthPort;
    oci.container.healthcheck.command = lib.mkDefault healthCmd;
    oci.container.stopSignal = lib.mkDefault "SIGQUIT";
    oci.container.extraPackages = [ pkgs.curl ];
  };
}
