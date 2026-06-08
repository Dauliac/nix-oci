# Shared: seccomp syscall filtering.
#
# Seccomp operates at the syscall boundary via BPF. It can filter
# *which syscalls* a process may invoke, but cannot inspect syscall
# arguments that are pointers (e.g. file paths — TOCTOU risk).
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
          ];
          default = "moderate";
          description = ''
            Predefined seccomp profile level:

            - `"strict"` — allowlist of ~60 syscalls. Suitable for
              static binaries, Go/Rust services. Blocks `mount`,
              `ptrace`, `execve`, and most process/namespace ops.

            - `"moderate"` — blocks ~44 dangerous syscalls (similar
              to Docker's default profile). Allows most normal
              operations.

            - `"web-server"` — strict base plus networking and
              threading syscalls. Suitable for HTTP servers.

            In the inner NixOS module, the profile auto-defaults to
            `"web-server"` when a known web server service (nginx,
            httpd) is detected.
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
