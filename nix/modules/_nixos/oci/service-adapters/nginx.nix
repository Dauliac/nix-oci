# nginx: run in foreground (daemon off) + auto-derive healthcheck + stop signal.
#
# NixOS nginx uses Type=forking with a PIDFile. In containers there is
# no init system, so we inject "daemon off;" to keep the master process
# in the foreground.
#
# Healthcheck: scans virtualHosts for known health paths (/health, /healthz,
# /nginx_status, stub_status), determines port/protocol from listen directives.
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

  healthPath =
    if hasStubStatus then
      "/nginx_status"
    else if healthLocation != null then
      healthLocation.path
    else
      "/";

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

  healthCmd = [
    "${pkgs.curl}/bin/curl"
    "-f"
    "--max-time"
    "5"
  ]
  ++ lib.optionals ssl [ "-k" ]
  ++ [ "${protocol}://localhost:${toString port}${healthPath}" ];
in
{
  config = lib.mkIf isNginx {
    services.nginx.appendConfig = lib.mkDefault "daemon off;";
    oci.container.healthcheck.command = lib.mkDefault healthCmd;
    # SIGQUIT: graceful shutdown — finish serving current requests, then exit.
    oci.container.stopSignal = lib.mkDefault "SIGQUIT";
    # curl must be in the container image for the healthcheck to work.
    environment.systemPackages = [ pkgs.curl ];
  };
}
