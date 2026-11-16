# Apache httpd: foreground mode + injected health endpoint + stop signal.
#
# NixOS httpd uses Type=forking. Apache requires -DFOREGROUND to stay
# in the foreground -- we wrap the package to always pass it.
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

  # Resolve the listen ports from the virtual hosts.
  #
  # The top-level `services.httpd.listen` this adapter used to read was
  # removed from nixpkgs via `mkRemovedOptionModule`, which throws on
  # access rather than leaving the attribute absent. `listen or [ ]`
  # therefore could not catch it, and every container with
  # `mainService = "httpd"` failed at eval with "The option
  # `services.httpd.listen' can no longer be used since it's been
  # removed."
  #
  # The derivation lives in the pure lib so it is unit-tested without
  # booting a VM. See `resolveHttpdListen` in nix/lib/oci.nix.
  ociLib = import ../../../lib/oci.nix { inherit lib; };

  listen = ociLib.resolveHttpdListen {
    virtualHosts = httpdCfg.virtualHosts or { };
  };

  healthUrl = "${
    if listen.usesSsl then "https" else "http"
  }://localhost:${toString listen.healthPort}/_nix_oci_health?auto";
in
{
  config = lib.mkIf isHttpd {
    # Every port the server binds, not just the first: these feed the
    # port/privilege coherence check, which needs to see 443 as well as
    # 80 to reason about NET_BIND_SERVICE.
    oci.container._output.detectedPorts = listen.detectedPorts;
    # Force the unit into the foreground by rewriting ExecStart, the
    # same way the dnsmasq, bind and postfix adapters do.
    #
    # NOT by wrapping services.httpd.package: this adapter used to read
    # `httpdCfg.package` to build a wrapper and then assign that wrapper
    # back to `services.httpd.package`, which is self-referential and
    # evaluates to "error: infinite recursion encountered". It went
    # unnoticed because the removed-option read of `services.httpd.listen`
    # threw first, masking it; fixing that exposed this.
    #
    # ExecStart mirrors nixpkgs' own (apache-httpd/default.nix), minus
    # the `@` prefix (argv[0] rewriting, pointless here) and plus
    # -DFOREGROUND.
    systemd.services.httpd.serviceConfig = {
      Type = lib.mkForce "simple";
      ExecStart = lib.mkForce "${httpdCfg.package}/bin/httpd -f /etc/httpd/httpd.conf -DFOREGROUND";
    };

    # Inject mod_status at a localhost-only endpoint
    services.httpd.extraConfig = ''
      <Location "/_nix_oci_health">
          SetHandler server-status
          Require local
      </Location>
    '';

    oci.container.healthcheck.command = lib.mkDefault (
      [
        "${pkgs.curl}/bin/curl"
        "-f"
        "--max-time"
        "5"
      ]
      # Only reachable over TLS: skip verification, since the probe
      # targets localhost and the container may carry no CA bundle.
      ++ lib.optional listen.usesSsl "-k"
      ++ [ healthUrl ]
    );
    # SIGWINCH: graceful stop -- finish serving current requests, then exit.
    oci.container.stopSignal = lib.mkDefault "SIGWINCH";
    oci.container.extraPackages = [ pkgs.curl ];
  };
}
