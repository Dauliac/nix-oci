# Runtime BDD test specs for performance.hwcaps.
#
# Verifies the glibc-hwcaps layer places CPU-optimized shared libraries
# under /lib/glibc-hwcaps/<level>/ inside the built image. The dynamic
# linker selects between these variants at process startup based on
# CPUID; here we only need to prove the payload is present.
#
# Runtime tests use the `succeeds` assertion: podman run --rm re-enters
# the built image with the given command and asserts non-zero exit +
# optional stdout match.
#
# Spec: openspec/changes/runtime-behavioral-test-coverage/specs/testing/runtime-behavior-verification/spec.md
#   Scenario: hwcaps library variants are present in image
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.performance-hwcaps-runtime = {
        # hwcaps enabled with x86-64-v3 optimised zlib -> variant must
        # appear under /lib/glibc-hwcaps/x86-64-v3/.
        runtime-x86_64-v3-library-present = {
          given = "a container with hwcaps enabled at level x86-64-v3 and libraries = [ zlib ]";
          "when" = "the container is entered and /lib/glibc-hwcaps/x86-64-v3 is inspected";
          "then" = "at least one optimised .so file is present";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            performance.enable = true;
            performance.hwcaps = {
              enable = true;
              levels = [ "x86-64-v3" ];
              libraries = [ pkgs.zlib ];
            };
          };
          assertions.succeeds = [
            {
              command = "${pkgs.busybox}/bin/busybox";
              args = "sh -c 'test -d /lib/glibc-hwcaps/x86-64-v3 && ${pkgs.busybox}/bin/busybox find /lib/glibc-hwcaps/x86-64-v3 -name *.so* -type f | head -n1 | grep -q .so && echo HWCAPS_V3_PRESENT'";
              stdout = "HWCAPS_V3_PRESENT";
            }
          ];
        };

        # hwcaps disabled -> the /lib/glibc-hwcaps directory must NOT exist.
        runtime-disabled-absent = {
          given = "a container with hwcaps disabled (default)";
          "when" = "the container is entered and /lib/glibc-hwcaps is inspected";
          "then" = "no hwcaps directory exists";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            performance.enable = true;
            performance.hwcaps.enable = false;
          };
          assertions.succeeds = [
            {
              command = "${pkgs.busybox}/bin/busybox";
              args = "sh -c 'if [ ! -d /lib/glibc-hwcaps ]; then echo HWCAPS_ABSENT; fi'";
              stdout = "HWCAPS_ABSENT";
            }
          ];
        };
      };
    };
}
