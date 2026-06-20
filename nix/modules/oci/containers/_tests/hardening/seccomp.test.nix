# BDD test specs for hardening.seccomp option.
#
# This is a flake-parts module (NOT a submodule module).
# Discovered by test-collector.nix via discoverModules(filter=test).
# Contributes to config.perSystem.test.oci.perContainer.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-seccomp = {
        eval-defaults = {
          given = "a container with hardening enabled and seccomp defaults";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds without error";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
          };
        };

        inspect-label-present = {
          given = "a container with seccomp moderate profile";
          "when" = "the OCI image is inspected";
          "then" = "the seccomp profile label is present";
          level = "inspect";
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
          assertions = {
            imageConfig.Labels = {
              "io.github.dauliac.nix-oci.hardening.seccomp-profile" = "moderate";
            };
          };
          exampleFile = ../../../../../../examples/flake/hardening/hardening-full-01.nix;
        };

        inspect-strict-profile = {
          given = "a container with seccomp strict profile";
          "when" = "the OCI image is inspected";
          "then" = "the seccomp profile label shows strict";
          level = "inspect";
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
          assertions = {
            imageConfig.Labels = {
              "io.github.dauliac.nix-oci.hardening.seccomp-profile" = "strict";
            };
          };
        };

        runtime-mount-blocked = {
          given = "a hardened container with seccomp and dropped capabilities";
          "when" = "a process tries to mount a tmpfs";
          "then" = "the mount is blocked (requires CAP_SYS_ADMIN, dropped by hardening)";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            entrypoint = [ "${pkgs.busybox}/bin/busybox" ];
          };
          testDependencies = [ pkgs.busybox ];
          assertions.fails = [
            {
              command = "${pkgs.busybox}/bin/busybox";
              args = "mount -t tmpfs none /mnt";
            }
          ];
        };
      };
    };
}
