# BIND/named: foreground mode + healthcheck via dig + stop signal.
#
# NixOS bind uses Type=forking. The -f flag keeps named in the
# foreground, which is required for containers without an init system.
#
# Healthcheck: queries "version.bind chaos txt" -- a standard BIND
# health check that returns the server version without needing any
# user-defined zones. Proves the DNS server is resolving queries.
#
# StopSignal: SIGTERM -- named shuts down cleanly on SIGTERM.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container;
  isNamed = cfg.mainService == "named";
in
{
  config = lib.mkIf isNamed {
    oci.container._output.detectedPorts = [ 53 ];
    services.bind.extraOptions = lib.mkDefault "-f";

    oci.container.healthcheck.command = lib.mkDefault [
      "${pkgs.dig}/bin/dig"
      "@127.0.0.1"
      "version.bind"
      "chaos"
      "txt"
      "+short"
      "+time=3"
    ];
    oci.container.stopSignal = lib.mkDefault "SIGTERM";
    environment.systemPackages = [ pkgs.dig ];
  };
}
