# Shared: AppArmor MAC (Mandatory Access Control) profile.
#
# AppArmor is a Linux Security Module (LSM) that provides pathname-based
# access control. Unlike seccomp (syscall filtering), AppArmor
# operates on pathnames and can restrict:
#
#   - File access (read/write/execute per path)
#   - Network access (TCP/UDP bind/connect)
#   - Capability usage (even more granular than cap drop)
#   - Mount operations (which fstype, where)
#   - User namespace creation (deny userns — blocks LPE class)
#
# Enforcement order at runtime:
#   seccomp (BPF) → capabilities (kernel) → AppArmor (LSM)
#
# AppArmor profiles are loaded on the HOST, not inside the container.
# The deploy module generates --security-opt apparmor=<profile-name>.
# The NixOS eval generates the profile content as a build output.
#
# LIMITATION: nixpkgs' podman package is built without AppArmor support
# (no "apparmor" Go build tag -- containers/common's apparmor.IsEnabled()
# stub unconditionally returns false, confirmed by reading podman's own
# vendored source). hardening.enable = true + apparmor.enable = true
# under the podman backend fails the build via a hardening/coherence.nix
# assertion rather than silently producing an unconfined container. Use
# backend = "docker" for working AppArmor enforcement (requires a
# /sbin/apparmor_parser compatibility shim on NixOS, since containerd's
# detection hardcodes that FHS path).
{ lib, ... }:
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

            Does NOT work under the "podman" backend: nixpkgs' podman is
            built without AppArmor support, so this combination fails
            the build (see hardening/coherence.nix). Use backend =
            "docker" instead.
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

            Enforced via AppArmor `deny userns,` rule.
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
            Enforced via AppArmor `deny ptrace (trace, tracedby, read, read),`
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
}
