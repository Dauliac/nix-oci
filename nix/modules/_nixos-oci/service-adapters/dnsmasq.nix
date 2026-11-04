# dnsmasq: healthcheck via DNS query + stop signal.
#
# dnsmasq runs in foreground by default in NixOS (--keep-in-foreground).
# No foreground adapter needed.
#
# Healthcheck: sends a DNS query to the configured listen address and port.
# Uses "localhost" as the query name -- dnsmasq will resolve it even without
# upstream servers configured (from /etc/hosts).
#
# StopSignal: SIGTERM -- dnsmasq exits cleanly on SIGTERM.
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
  firstAddr = builtins.head (lib.splitString "," listenAddr);
  # A wildcard bind address ("0.0.0.0"/"*"/"::") is not a usable query
  # target: dig has to connect to a concrete address, and sending a
  # UDP query to 0.0.0.0 is unreliable (varies by kernel/resolver and
  # reliably times out in some sandboxes). dnsmasq bound to a wildcard
  # address also answers on loopback, so query that instead.
  addr =
    if
      builtins.elem firstAddr [
        "0.0.0.0"
        "*"
        "::"
      ]
    then
      "127.0.0.1"
    else
      firstAddr;
in
{
  config = lib.mkIf isDnsmasq {
    oci.container._output.detectedPorts = [ (dnsmasqCfg.settings.port or 53) ];
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
    oci.container.extraPackages = [ pkgs.dig ];

    # nixpkgs' `services.dnsmasq` module adds
    #   conf-file = /etc/dnsmasq-conf.conf
    #   resolv-file = /etc/dnsmasq-resolv.conf
    # to the generated dnsmasq.conf whenever `resolveLocalQueries` is
    # true (the default). On a normal NixOS host those paths are
    # created by the service's preStart `touch /etc/dnsmasq-{conf,
    # resolv}.conf`. Inside a container the entrypoint script does
    # run those touches, but the OCI image's /etc is a nix-store-
    # backed directory where the overlay cannot persist the new
    # files reliably: dnsmasq --test then exits with
    #   dnsmasq: cannot read /etc/dnsmasq-conf.conf: No such file ...
    #   exit=3 (EC_FILE)
    # which systemd surfaces as `status=3/NOTIMPLEMENTED`.
    #
    # Containers never want the local-resolver wiring anyway (there
    # is no /etc/resolv.conf to splice ourselves into), so disable
    # `resolveLocalQueries` by default. Both config lines disappear
    # from the generated dnsmasq.conf, the touches become
    # irrelevant, and dnsmasq --test passes. Consumers who need the
    # local resolver on their host can still opt back in.
    services.dnsmasq.resolveLocalQueries = lib.mkDefault false;

    # nixpkgs' `services.dnsmasq` hard-codes a D-Bus-dependent ExecStart:
    #   Type = "dbus";
    #   BusName = "uk.org.thekelleys.dnsmasq";
    #   ExecStart = "${dnsmasq}/bin/dnsmasq -k --enable-dbus --user=dnsmasq ...";
    # Containers run with no dbus daemon, so `--enable-dbus` makes dnsmasq
    # exit immediately with status 5 (ExitFailure, surfaced by systemd as
    # NOTINSTALLED), and the container crash-loops. Strip the D-Bus
    # dependency here: the service becomes a plain `simple` unit, the
    # ExecStart drops `--enable-dbus`, and the BusName / Type fields are
    # cleared. Reload stays as SIGHUP (the one `kill -HUP $MAINPID`
    # command does not need dbus).
    #
    # --pid-file=/tmp/dnsmasq.pid: even with -k (keep in foreground),
    # dnsmasq writes a pidfile when started as root, defaulting to
    # /var/run/dnsmasq.pid. The OCI image has no /var/run, and dnsmasq
    # treats the failed O_EXCL open as fatal:
    #   dnsmasq: failed to open pidfile /var/run/dnsmasq.pid: No such file ...
    #   exit=3 (EC_FILE, surfaced by systemd as NOTIMPLEMENTED)
    # /tmp exists in every nix-oci rootfs and each container start gets a
    # fresh overlay, so the O_EXCL create never collides with a stale file.
    # (Verified: `--pid-file=/dev/null` fails with EEXIST and an empty
    # `--pid-file=` is a config error, so a real path is the only option.)
    systemd.services.dnsmasq.serviceConfig = {
      Type = lib.mkForce "simple";
      BusName = lib.mkForce null;
      ExecStart = lib.mkForce "${dnsmasqCfg.package}/bin/dnsmasq -k --user=dnsmasq --pid-file=/tmp/dnsmasq.pid -C ${dnsmasqCfg.configFile}";
    };
  };
}
