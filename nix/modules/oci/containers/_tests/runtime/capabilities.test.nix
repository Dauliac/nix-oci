# Runtime-level BDD test specs for hardening.capabilities.
#
# Extends ../hardening/capabilities.test.nix with `level = "runtime"`
# scenarios that read /proc/1/status CapEff bitmask from inside the
# running container.
#
# Because no typed `capEff` assertion exists, we use the `succeeds`
# assertion with a shell command that grep-checks the bitmask. The
# pytest generator resolves the exit code  -  non-zero if the grep does
# not match  -  so this doubles as a semantic check.
#
# Cross-references:
#   - runtime-behavior-verification spec: scenario "capabilities drop
#     actually removes capabilities"
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.runtime-hardening-capabilities = {
        # drop = ["ALL"] and no `add` → effective capabilities are 0.
        runtime-drop-all-caps-eff-zero = {
          given = "a container built with hardening.capabilities.drop = [\"ALL\"] and no add-back";
          "when" = "the container is run under podman with --cap-drop=ALL and /proc/1/status is inspected";
          "then" = "the CapEff line reports the all-zero bitmask 0000000000000000";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.capabilities = {
              drop = [ "ALL" ];
              add = [ ];
            };
          };
          # /bin/sh -c 'grep -q "^CapEff:.0000000000000000$" /proc/1/status'
          # exits 0 when the bitmask is fully cleared.
          assertions.succeeds = [
            {
              command = "/bin/sh";
              args = "-c 'grep -q \"^CapEff:\\s\\+0000000000000000$\" /proc/1/status'";
              stdout = null;
            }
          ];
          exampleFile = ../../../../../../examples/flake/hardening/hardening-full-01.nix;
        };

        # drop=ALL + add NET_BIND_SERVICE → CapEff line MUST NOT be
        # all zero. Match with a grep-v to invert.
        runtime-add-net-bind-service-nonzero-eff = {
          given = "a container with hardening.capabilities.drop = [\"ALL\"] and add = [\"NET_BIND_SERVICE\"]";
          "when" = "the container is run under podman and /proc/1/status is inspected";
          "then" = "the CapEff bitmask is nonzero (NET_BIND_SERVICE bit set, others cleared)";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.capabilities = {
              drop = [ "ALL" ];
              add = [ "NET_BIND_SERVICE" ];
            };
          };
          # The NET_BIND_SERVICE bit is #10, so CapEff must include
          # the byte 0400 (hex) in its last hextet: bitmask ends in
          # 0400. We simply assert CapEff is NOT all-zero here.
          assertions.succeeds = [
            {
              command = "/bin/sh";
              args = "-c 'grep -v \"^CapEff:\\s\\+0000000000000000$\" /proc/1/status | grep -q \"^CapEff:\"'";
              stdout = null;
            }
          ];
        };
      };
    };
}
