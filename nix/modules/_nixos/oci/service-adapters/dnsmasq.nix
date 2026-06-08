# dnsmasq: healthcheck via DNS query + stop signal.
#
# dnsmasq runs in foreground by default in NixOS (--keep-in-foreground).
# No foreground adapter needed.
#
# Healthcheck: sends a DNS query to the configured listen address and port.
# Uses "localhost" as the query name — dnsmasq will resolve it even without
# upstream servers configured (from /etc/hosts).
#
# StopSignal: SIGTERM — dnsmasq exits cleanly on SIGTERM.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container;
  isDnsmasq = cfg.mainService == "dnsmasq";
  dnsmasqCfg = config.services.dnsmasq;
  port = toString (dnsmasqCfg.settings.port or 53);
  rawAddr = dnsmasqCfg.settings.listen-address or "127.0.0.1";
  # NixOS settings can produce a list or comma-separated string
  listenAddr = if builtins.isList rawAddr then builtins.head rawAddr else rawAddr;
  # Use first address if multiple are configured
  addr = builtins.head (lib.splitString "," listenAddr);
in
{
  config = lib.mkIf isDnsmasq {
    oci.container.healthcheck.command = lib.mkDefault [
      "${pkgs.dig}/bin/dig"
      "@${addr}"
      "-p"
      port
      "localhost"
      "+short"
      "+time=3"
    ];
    oci.container.stopSignal = lib.mkDefault "SIGTERM";
    environment.systemPackages = [ pkgs.dig ];
  };
}
