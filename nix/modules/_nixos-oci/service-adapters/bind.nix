# BIND/named: foreground mode + healthcheck via dig + stop signal.
#
# NixOS creates `systemd.services.bind` (not `named`), so
# `oci.container.mainService` must be `"bind"` to match this adapter
# and the entrypoint extractor at
# `nix/modules/_nixos-oci/entrypoint/lib.nix:29`. The historical
# `"named"` spelling matched neither the systemd unit name nor the
# NixOS option path, so the adapter silently never fired.
#
# NixOS bind uses Type=forking and daemonises. In a container there is
# no init to reap daemonised children, so systemd (PID 1 for the
# oneshot container runner) never sees the real workload exit code and
# the container falls into a restart loop. We override the service to
# `Type = simple` and rebuild the ExecStart with `-g` (foreground +
# log to stderr), which is what every container runtime expects.
#
# `services.bind.extraOptions` cannot be used: nixpkgs splices it
# verbatim into the `options { ... }` block of named.conf, not onto
# the command line. Passing `-f` or `-g` through that path turns the
# config file into a syntax error ("unknown option: -f") and named
# exits before serving any queries.
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
  isBind = cfg.mainService == "bind";
in
{
  config = lib.mkIf isBind {
    oci.container._output.detectedPorts = [ 53 ];

    # Use the typed `extraArgs` list that nixpkgs' bind module appends
    # verbatim to the ExecStart command line, instead of the misnamed
    # `extraOptions` (which splices into named.conf, see header
    # comment). `-g` runs named in the foreground AND logs to stderr,
    # which is both what the container needs to stay alive and what
    # systemd / podman journal expect for log capture.
    services.bind.extraArgs = [ "-g" ];

    # Nixpkgs ships bind with `Type = "forking"` to work around a
    # Debian bug (bugs.debian.org/900788). In a container there is no
    # init to reap the forked worker, so systemd never observes the
    # real exit code and the oneshot container runner enters a
    # restart loop. `-g` already keeps named in the foreground; pair
    # it with `Type = simple` so the service never daemonises.
    systemd.services.bind.serviceConfig.Type = lib.mkForce "simple";

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
    oci.container.extraPackages = [ pkgs.dig ];
  };
}
