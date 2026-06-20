# BDD test specs for hardening.apparmor option.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-apparmor = {
        eval-defaults = {
          given = "a container with default hardening.apparmor";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
          };
        };

        eval-with-hardening = {
          given = "a container with hardening enabled including apparmor";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds with apparmor configured";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
            hardening.enable = true;
          };
        };

        runtime-proc-write-blocked = {
          given = "a hardened container with default AppArmor profile";
          "when" = "a process tries to write to /proc/sysrq-trigger";
          "then" = "the write is denied by the container runtime security";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            entrypoint = [ "${pkgs.busybox}/bin/busybox" ];
          };
          testDependencies = [ pkgs.busybox ];
          # With default podman security (AppArmor or seccomp), writing
          # to sensitive /proc entries should fail.
          assertions.fails = [
            {
              command = "${pkgs.busybox}/bin/busybox";
              args = "sh -c 'echo b > /proc/sysrq-trigger'";
            }
          ];
        };
      };
    };
}
