# Caddy: healthcheck via built-in admin API + stop signal.
#
# Caddy runs in foreground by default -- no adapter needed for that.
# Caddy has a built-in admin API at localhost:2019 (enabled by default).
# We use it as a native healthcheck -- no injection needed.
#
# StopSignal: SIGTERM -- Caddy handles it gracefully with connection draining.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container;
  isCaddy = cfg.mainService == "caddy";
in
{
  config = lib.mkIf isCaddy {
    oci.container._output.detectedPorts = [ 2019 ];
    oci.container.healthcheck.command = lib.mkDefault [
      "${pkgs.curl}/bin/curl"
      "-f"
      "--max-time"
      "5"
      "http://localhost:2019/config/"
    ];
    oci.container.stopSignal = lib.mkDefault "SIGTERM";
    oci.container._output.adapterPackages = [ pkgs.curl ];
  };
}
