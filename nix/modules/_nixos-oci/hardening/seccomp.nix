{ lib, ... }:
{
  options.oci.container.hardening.seccomp = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable seccomp profile.";
        };
        profile = lib.mkOption {
          type = lib.types.enum [
            "strict"
            "moderate"
            "web-server"
            "database"
            "gpu-compute"
          ];
          default = "moderate";
          description = "Seccomp profile level.";
        };
        mode = lib.mkOption {
          type = lib.types.enum [
            "enforce"
            "audit"
          ];
          default = "enforce";
          description = ''
            Seccomp enforcement mode:

            - `"enforce"` -- block disallowed syscalls with SCMP_ACT_ERRNO.
            - `"audit"` -- log disallowed syscalls with SCMP_ACT_LOG but
              allow them. Useful for profile discovery and testing.
          '';
        };
        customProfileJson = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Custom seccomp profile JSON.";
        };
      };
    };
    default = { };
    description = "Seccomp syscall filtering configuration.";
  };
}
