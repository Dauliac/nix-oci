# BDD test specs for the dnsmasq service adapter (deploy level).
#
# Covers requirement `Untested service adapters end-to-end` /
# scenario `dnsmasq resolves a configured hosts entry` in
# `openspec/changes/runtime-behavioral-test-coverage/specs/testing/deploy-runtime-verification/spec.md`.
#
# The dnsmasq adapter's own healthcheck is dependency-free (bash's
# built-in UDP redirection; see the adapter's header comment), so
# dnsmasq's production image closure no longer includes a DNS
# client. The test harness's `assertions.succeeds` step, however,
# re-runs this exact image with `command` as the entrypoint (see
# `nix/modules/oci/testing/_python-gen.nix`'s `mkSucceeds`), so `dig`
# still has to be present *inside the image* for the assertion below
# to exec at all -- added here, test-local only, so production
# consumers of the adapter keep the smaller closure.
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
                  { pkgs, ... }:
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
                    # Test-only: the `dig` client the assertion below
                    # execs inside this image. Not part of the
                    # production adapter (see header comment).
                    oci.container.extraPackages = [ pkgs.dig ];
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
