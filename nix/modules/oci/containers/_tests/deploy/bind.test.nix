# BDD test specs for the BIND (named) service adapter (deploy level).
#
# Covers requirement `Untested service adapters end-to-end` /
# scenario `BIND resolves version.bind` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# The bind adapter (`nix/modules/_nixos-oci/service-adapters/bind.nix`)
# runs named with `-f` (foreground) and pulls in dig for the healthcheck.
# The runtime probe queries version.bind chaos TXT, a standard BIND
# health check that returns the server version string without needing
# any user-declared zones.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-bind = {
        deploy-bind-resolves-version-bind = {
          given = "a BIND container with mainService = named listening on port 53";
          "when" = "dig @localhost -p <port> version.bind chaos txt";
          "then" = "the TXT record is non-empty";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            isRoot = true;
            ports = [ "5354:53/udp" ];
            nixosConfig = {
              # Matches the systemd unit name NixOS actually creates
              # (`systemd.services.bind`); the bind service adapter at
              # `nix/modules/_nixos-oci/service-adapters/bind.nix`
              # fires on this value and overrides ExecStart with `-g`
              # + Type=simple so the daemon stays in foreground inside
              # the container.
              mainService = "bind";
              modules = [
                (
                  { ... }:
                  {
                    services.bind = {
                      enable = true;
                      listenOn = [ "any" ];
                      # No user zones needed; version.bind chaos TXT is
                      # served without any configured zones.
                      cacheNetworks = [ "0.0.0.0/0" ];
                      forwarders = [ ];
                    };
                  }
                )
              ];
            };
          };
          assertions.succeeds = [
            {
              command = "${pkgs.dig}/bin/dig";
              args = "@127.0.0.1 -p 5354 version.bind chaos txt +short +time=3";
              # BIND replies with its version string in quotes; look
              # for the leading quote as a non-empty signal.
              stdout = "\"";
            }
          ];
        };
      };
    };
}
