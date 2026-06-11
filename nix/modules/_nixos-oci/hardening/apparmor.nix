# Inner NixOS eval: AppArmor options forwarded from flake-parts.
#
# Used by outputs.nix for profile generation and by coherence.nix
# for cross-backend coherence assertions.
{ lib, ... }:
{
  options.oci.container.hardening.apparmor = lib.mkOption {
    type = lib.types.submodule {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable AppArmor profile generation.";
        };
        mode = lib.mkOption {
          type = lib.types.enum [
            "enforce"
            "complain"
          ];
          default = "enforce";
          description = "AppArmor enforcement mode.";
        };
        denyUserNamespace = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Deny user namespace creation.";
        };
        denyMount = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Deny mount operations.";
        };
        denyPtrace = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Deny ptrace of other processes.";
        };
        customProfile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "Custom AppArmor profile (overrides computed rules).";
        };
      };
    };
    default = { };
    description = "AppArmor MAC profile configuration.";
  };
}
