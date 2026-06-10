# Shared: seccomp syscall filtering.
#
# Seccomp operates at the syscall boundary via BPF. It can filter
# *which syscalls* a process may invoke, and can also filter
# integer syscall arguments (e.g. clone flags, ioctl commands,
# socket address families).
#
# This is complementary to Landlock (which operates at VFS level
# and can restrict *which files/ports* are accessible).
{ lib, ... }:
{
  options.hardening.seccomp = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable a custom seccomp profile for this container.";
        };

        profile = lib.mkOption {
          type = lib.types.enum [
            "strict"
            "moderate"
            "web-server"
            "database"
          ];
          default = "moderate";
          description = ''
            Predefined seccomp profile level:

            - `"strict"` -- allowlist of ~60 syscalls. Suitable for
              static binaries, Go/Rust services. Blocks `mount`,
              `ptrace`, `execve`, and most process/namespace ops.

            - `"moderate"` -- blocks ~50 dangerous syscalls including
              io_uring and memfd_create. All profiles include
              argument-level filtering for clone (block namespace
              creation), socket (block AF_NETLINK/AF_PACKET), and
              ioctl (block TIOCSTI/TIOCLINUX terminal injection).

            - `"web-server"` -- strict base plus networking and
              threading syscalls. Suitable for HTTP servers.

            - `"database"` -- web-server base plus memory management
              syscalls (fadvise64, msync, mincore). Suitable for
              PostgreSQL, Redis, and similar services.

            In the inner NixOS module, the profile auto-defaults to
            `"web-server"` when a known web server service (nginx,
            httpd) is detected, and `"database"` when PostgreSQL
            or Redis is detected.
          '';
        };

        mode = lib.mkOption {
          type = lib.types.enum [
            "enforce"
            "audit"
          ];
          default = "enforce";
          description = ''
            Seccomp enforcement mode:

            - `"enforce"` -- block disallowed syscalls with
              SCMP_ACT_ERRNO (default).
            - `"audit"` -- log disallowed syscalls with SCMP_ACT_LOG
              but allow them. Useful for profile discovery and
              testing before switching to enforce.
          '';
        };

        customProfileJson = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Path to a custom seccomp profile JSON file following the
            OCI runtime specification format. When set, overrides
            the `profile` option.
          '';
        };
      };
    };
    default = { };
    description = "Seccomp syscall filtering configuration.";
  };
}
