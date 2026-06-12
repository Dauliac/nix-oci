# Shared: AppArmor MAC (Mandatory Access Control) profile.
#
# AppArmor is a Linux Security Module (LSM) that provides pathname-based
# access control. Unlike seccomp (syscall filtering) and Landlock
# (VFS/inode-level), AppArmor operates on pathnames and can restrict:
#
#   - File access (read/write/execute per path)
#   - Network access (TCP/UDP bind/connect)
#   - Capability usage (even more granular than cap drop)
#   - Mount operations (which fstype, where)
#   - User namespace creation (deny userns_create — blocks LPE class)
#
# Enforcement order at runtime:
#   seccomp (BPF) → capabilities (kernel) → AppArmor (LSM) → Landlock (LSM)
#
# AppArmor profiles are loaded on the HOST, not inside the container.
# The deploy module generates --security-opt apparmor=<profile-name>.
# The NixOS eval generates the profile content as a build output.
{
  lib,
  pkgs,
  ...
}:
{
  options.hardening.apparmor = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Enable AppArmor profile generation for this container.

            When enabled, a tailored AppArmor profile is generated as a
            build output. The deploy module references it via
            `--security-opt apparmor=<profile>`.

            Requires the target host to have AppArmor enabled
            (kernel LSM + apparmor_parser). On NixOS, set
            `security.apparmor.enable = true`.
          '';
        };

        mode = lib.mkOption {
          type = lib.types.enum [
            "enforce"
            "complain"
          ];
          default = "enforce";
          description = ''
            AppArmor enforcement mode:

            - `"enforce"` -- violations are blocked and logged (default).
              Use for production.
            - `"complain"` -- violations are logged but NOT blocked.
              Useful for profile discovery before switching to enforce.
          '';
        };

        denyUserNamespace = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Deny user namespace creation inside the container.

            Prevents the class of Local Privilege Escalation (LPE)
            vulnerabilities where unprivileged processes exploit userns
            to reach normally-root-only kernel code paths
            (CVE-2023-2640, CVE-2023-32629, etc.).

            Enforced via AppArmor `deny userns_create,` rule.
            Complementary to seccomp clone(CLONE_NEWUSER) arg filter
            and capability drop SYS_ADMIN.
          '';
        };

        denyMount = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Deny mount operations inside the container.

            Prevents filesystem remounting, overlay stacking, and
            bind-mount escape attacks. Enforced via AppArmor
            `deny mount,` rule.
          '';
        };

        denyPtrace = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Deny ptrace of other processes.

            Prevents process inspection and memory manipulation attacks.
            Enforced via AppArmor `deny ptrace (read, read, trace, traceby),`
            rule.
          '';
        };

        customProfile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = ''
            Path to a custom AppArmor profile file. When set, overrides
            ALL computed profile rules. The profile must be a valid
            AppArmor profile file.

            Note: cross-backend coherence checks cannot verify custom
            profiles — you take full responsibility for correctness.
          '';
        };
      };
    };
    default = { };
    description = "AppArmor MAC profile configuration.";
  };

  config._tests.hardening-apparmor = {
    level = "eval";
    default = {
      package = pkgs.hello;
      hardening.enable = true;
    };
    override = {
      package = pkgs.hello;
      hardening.enable = true;
      hardening.apparmor = {
        enable = true;
        mode = "enforce";
      };
    };
    assertions = {
      imageConfig = {
        Labels."io.github.dauliac.nix-oci.hardening.apparmor-enabled" = "true";
      };
    };
  };
}
