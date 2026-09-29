# BDD test specs for the dnsmasq service adapter (deploy level).
#
# Covers requirement `Untested service adapters end-to-end` /
# scenario `dnsmasq resolves a configured hosts entry` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# The dnsmasq adapter runs the daemon in the foreground by default
# and injects a dig-based healthcheck. The runtime probe queries
# a static hosts-entry via the VM host's port map.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.deploy-dnsmasq = {
        deploy-dnsmasq-resolves-hosts-entry = {
          given = "a dnsmasq container with a static hosts entry `myservice 10.0.0.1`";
          "when" = "dig @localhost -p <port> myservice";
          "then" = "dig returns 10.0.0.1";
          level = "deploy";
          mode = "daemon";
          target = "oci";
          container = {
            isRoot = true;
            ports = [ "5355:5353/udp" ];
            nixosConfig = {
              mainService = "dnsmasq";
              modules = [
                (
                  { ... }:
                  {
                    services.dnsmasq = {
                      enable = true;
                      settings = {
                        listen-address = "0.0.0.0";
                        port = 5353;
                        no-resolv = true;
                        # inline hosts-file entry
                        address = [
                          "/myservice/10.0.0.1"
                        ];
                      };
                    };
                  }
                )
              ];
            };
          };
          assertions.succeeds = [
            {
              command = "${pkgs.dig}/bin/dig";
              args = "@127.0.0.1 -p 5355 myservice +short +time=3";
              stdout = "10.0.0.1";
            }
          ];
        };
      };
    };
}
