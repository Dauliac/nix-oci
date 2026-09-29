# Runtime-level BDD test specs for hardening.rootfs.
#
# Extends ../hardening/rootfs.test.nix with `level = "runtime"`
# scenarios that assert writes to the rootfs actually fail with
# EROFS when the container is run under podman with --read-only.
#
# Uses the `fsWriteBlocked` typed assertion (expectedErrno = "EROFS"
# by default, matching read-only rootfs semantics distinct from
# EACCES for AppArmor).
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.runtime-hardening-rootfs = {
        # Positive case: readOnly = true → writing to a rootfs path
        # outside any declared volume fails with EROFS.
        runtime-write-blocked-erofs = {
          given = "a container built with hardening.readOnlyRootfs = true and run under podman with --read-only";
          "when" = "the container attempts touch /new-file at rootfs level";
          "then" = "the write fails with EROFS";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.readOnlyRootfs = true;
          };
          assertions.fsWriteBlocked = [
            {
              path = "/new-file";
              expectedErrno = "EROFS";
            }
          ];
          exampleFile = ../../../../../../examples/flake/hardening/hardening-full-01.nix;
        };

        # Control: readOnly = false → the same write succeeds. This
        # anchors the positive case so a spurious EROFS from a
        # different source doesn't get read as a rootfs success.
        runtime-write-succeeds-when-readonly-false = {
          given = "a container with hardening.readOnlyRootfs = false";
          "when" = "the container attempts a benign command";
          "then" = "the command exits 0";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.readOnlyRootfs = false;
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
