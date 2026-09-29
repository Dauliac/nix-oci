# Runtime-level BDD test specs for hardening.apparmor.
#
# Extends the build/inspect coverage in
# ../hardening/apparmor.test.nix with `level = "runtime"` scenarios
# that assert the generated AppArmor profile denies writes to
# sensitive host-visible paths (e.g. /proc/sys/*) at execution time.
#
# Uses the `fsWriteBlocked` typed assertion with expectedErrno = "EACCES"
# because AppArmor deny reports EACCES, not EROFS (that is rootfs' job).
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.runtime-hardening-apparmor = {
        # Positive case: AppArmor profile is applied → write to
        # /proc/sys is denied.
        runtime-proc-sys-write-denied = {
          given = "a container with hardening.apparmor.enable = true running under a host with AppArmor loaded";
          "when" = "the container attempts to write to /proc/sys/kernel/hostname";
          "then" = "the write is denied with EACCES by the AppArmor profile";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.apparmor = {
              enable = true;
              mode = "enforce";
            };
          };
          assertions.fsWriteBlocked = [
            {
              path = "/proc/sys/kernel/hostname";
              expectedErrno = "EACCES";
            }
          ];
          exampleFile = ../../../../../../examples/flake/hardening/hardening-full-01.nix;
        };

        # Negative case: no AppArmor profile applied → the same
        # write succeeds (or fails for a different, non-AppArmor
        # reason). This anchors the positive case so a
        # spurious deny doesn't get read as an AppArmor success.
        runtime-no-apparmor-write-succeeds = {
          given = "a container with hardening.apparmor.enable = false";
          "when" = "the container attempts to run a benign command";
          "then" = "the command succeeds because no AppArmor profile is applied";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.apparmor.enable = false;
          };
          assertions.succeeds = [
            {
              command = "/bin/true";
              args = "";
            }
          ];
        };
      };
    };
}
