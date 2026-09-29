# Runtime-level BDD test specs for hardening.seccomp.
#
# These extend the build/inspect coverage in
# ../hardening/seccomp.test.nix with `level = "runtime"` scenarios
# that assert the seccomp profile actually blocks disallowed syscalls
# at execution time (per runtime-behavior-verification spec).
#
# Assertions use the new typed vocabulary:
#   - `syscallBlocked` for EPERM-on-disallowed cases
#   - `succeeds`       for allowed-syscall smoke checks
#
# Full VM boots that actually exercise these are gated to CI (see
# openspec/changes/runtime-behavioral-test-coverage/design.md). The
# specs here declare the intent so the collector picks them up and
# the pytest generator emits the verification code.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.runtime-hardening-seccomp = {
        # Strict profile: `mount` is not on the allowlist.
        runtime-strict-blocks-mount = {
          given = "a container built with hardening.seccomp.profile = \"strict\" and run under podman with the seccomp profile applied";
          "when" = "a probe binary invokes the mount(2) syscall";
          "then" = "mount(2) is denied with EPERM and the probe exits nonzero";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.seccomp = {
              enable = true;
              profile = "strict";
            };
          };
          assertions.syscallBlocked = [
            {
              probe = "/bin/mount";
              args = "-t tmpfs none /mnt";
              syscall = "mount";
              expectedErrno = "EPERM";
            }
          ];
          exampleFile = ../../../../../../examples/flake/hardening/hardening-full-01.nix;
        };

        # Strict profile: `unshare` is blocked (namespace creation).
        runtime-strict-blocks-unshare = {
          given = "a container built with hardening.seccomp.profile = \"strict\"";
          "when" = "a probe binary invokes unshare(2) to create a new namespace";
          "then" = "unshare(2) is denied with EPERM and the probe exits nonzero";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.seccomp = {
              enable = true;
              profile = "strict";
            };
          };
          assertions.syscallBlocked = [
            {
              probe = "/bin/unshare";
              args = "--user --pid --mount echo ok";
              syscall = "unshare";
              expectedErrno = "EPERM";
            }
          ];
        };

        # Strict profile: an allowed syscall (`getpid` via `sh -c :`)
        # still succeeds so the probe doesn't mistake profile failure
        # for total lockdown.
        runtime-strict-allows-basic-syscalls = {
          given = "a container built with hardening.seccomp.profile = \"strict\"";
          "when" = "a benign process using only allowlisted syscalls runs";
          "then" = "the process exits 0 and the seccomp profile does not block basic execution";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.seccomp = {
              enable = true;
              profile = "strict";
            };
          };
          assertions.succeeds = [
            {
              command = "/bin/true";
              args = "";
            }
          ];
        };

        # Moderate profile: blocks `unshare` (namespaces off) while
        # allowing a broader syscall set than strict.
        runtime-moderate-blocks-unshare = {
          given = "a container built with hardening.seccomp.profile = \"moderate\"";
          "when" = "a probe binary invokes unshare(2)";
          "then" = "unshare(2) is denied with EPERM";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.seccomp = {
              enable = true;
              profile = "moderate";
            };
          };
          assertions.syscallBlocked = [
            {
              probe = "/bin/unshare";
              args = "--user echo ok";
              syscall = "unshare";
              expectedErrno = "EPERM";
            }
          ];
        };

        # Web-server profile: a workload profile ("custom-syscall"
        # variant per the tasks list)  -  narrower than moderate but
        # broader than strict. Verifies the profile-specific block
        # of `unshare` while still allowing socket syscalls.
        runtime-web-server-blocks-unshare = {
          given = "a container built with hardening.seccomp.profile = \"web-server\"";
          "when" = "a probe binary invokes unshare(2)";
          "then" = "unshare(2) is denied with EPERM under the web-server profile";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.seccomp = {
              enable = true;
              profile = "web-server";
            };
          };
          assertions.syscallBlocked = [
            {
              probe = "/bin/unshare";
              args = "--user echo ok";
              syscall = "unshare";
              expectedErrno = "EPERM";
            }
          ];
        };
      };
    };
}
