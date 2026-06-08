# Apache httpd: foreground mode + injected health endpoint + stop signal.
#
# NixOS httpd uses Type=forking. Apache requires -DFOREGROUND to stay
# in the foreground — we wrap the package to always pass it.
#
# Healthcheck: injects mod_status at /_nix_oci_health, restricted to
# localhost. Provides server uptime, request count, and worker status.
#
# StopSignal: SIGWINCH for graceful stop (finish current requests).
# SIGTERM does an immediate stop; SIGWINCH is the Apache "graceful stop".
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container;
  httpdCfg = config.services.httpd;
  originalPkg = httpdCfg.package;

  isHttpd = cfg.mainService == "httpd";

  httpdForeground = pkgs.symlinkJoin {
    name = "httpd-foreground";
    paths = [ originalPkg ];
    postBuild = ''
      rm "$out/bin/httpd"
      cat > "$out/bin/httpd" <<'WRAPPER'
      #!/bin/sh
      exec ${originalPkg}/bin/httpd -DFOREGROUND "$@"
      WRAPPER
      chmod +x "$out/bin/httpd"
    '';
  };

  # Determine the first listen port
  listenAddrs = httpdCfg.listen or [ ];
  firstPort = if listenAddrs != [ ] then (builtins.head listenAddrs).port or 80 else 80;
in
{
  config = lib.mkIf isHttpd {
    services.httpd.package = lib.mkForce httpdForeground;
    systemd.services.httpd.serviceConfig.Type = lib.mkForce "simple";

    # Inject mod_status at a localhost-only endpoint
    services.httpd.extraConfig = ''
      <Location "/_nix_oci_health">
          SetHandler server-status
          Require local
      </Location>
    '';

    oci.container.healthcheck.command = lib.mkDefault [
      "${pkgs.curl}/bin/curl"
      "-f"
      "--max-time"
      "5"
      "http://localhost:${toString firstPort}/_nix_oci_health?auto"
    ];
    # SIGWINCH: graceful stop — finish serving current requests, then exit.
    oci.container.stopSignal = lib.mkDefault "SIGWINCH";
    environment.systemPackages = [ pkgs.curl ];
  };
}
