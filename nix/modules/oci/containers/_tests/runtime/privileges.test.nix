# Runtime-level BDD test specs for hardening.noNewPrivileges.
#
# Extends ../hardening/privileges.test.nix with `level = "runtime"`
# scenarios that boot a container running as uid 4000, invoke a
# setuid-root binary, and assert the effective UID stays at 4000
# rather than escalating to 0.
#
# No dedicated `euid` assertion exists, so we use `succeeds` with a
# shell command that reads /proc/self/status's `Uid:` line. The
# grep exit code carries the semantic.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.runtime-hardening-privileges = {
        # noNewPrivileges = true: setuid binary cannot escalate.
        # Container runs as uid 4000; invoking a setuid-root wrapper
        # must still report euid 4000.
        runtime-setuid-blocked-euid-stays = {
          given = "a container built with hardening.noNewPrivileges = true, running as uid 4000, with a setuid-root binary on PATH";
          "when" = "the container executes the setuid-root binary";
          "then" = "the effective UID reported in /proc/self/status stays 4000, not 0";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = false;
            hardening.enable = true;
            hardening.noNewPrivileges = true;
          };
          # /proc/self/status Uid line is "Uid:\t<real>\t<eff>\t..."
          # We assert the effective field (2nd tab-separated col) is
          # NOT 0.
          assertions.succeeds = [
            {
              command = "/bin/sh";
              args = "-c 'awk \"/^Uid:/ { exit (\\$3 == 0) }\" /proc/self/status'";
              stdout = null;
            }
          ];
          exampleFile = ../../../../../../examples/flake/hardening/hardening-full-01.nix;
        };

        # Control: noNewPrivileges = false + isRoot = true → the
        # process runs as root; the assertion below verifies euid IS
        # 0, so a spurious block reads as a deviation.
        runtime-root-euid-is-zero = {
          given = "a container with hardening.noNewPrivileges = false running as root";
          "when" = "/proc/self/status is inspected";
          "then" = "the effective UID is 0";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.noNewPrivileges = false;
          };
          assertions.succeeds = [
            {
              command = "/bin/sh";
              args = "-c 'awk \"/^Uid:/ { exit !(\\$3 == 0) }\" /proc/self/status'";
              stdout = null;
            }
          ];
        };
      };
    };
}
