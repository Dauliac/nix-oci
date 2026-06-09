# OCI mkSeccompProfile - Generate a seccomp profile JSON from hardening config
#
# Provides three predefined profiles using different strategies:
#   - strict:     SCMP_ACT_ERRNO default, allowlist ~60 essential syscalls
#   - moderate:   SCMP_ACT_ALLOW default, blocklist ~44 dangerous syscalls
#   - web-server: SCMP_ACT_ERRNO default, allowlist strict + network + threading
#
# Seccomp operates at the syscall boundary via BPF -- it controls *which
# operations* a process can invoke, complementary to Landlock (which
# controls *which resources* are accessible).
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    {
      nix-lib.lib.oci.mkSeccompProfile = {
        type = lib.types.functionTo lib.types.package;
        description = ''
          Generate a seccomp profile JSON file from hardening configuration.

          When `hardening.seccomp.customProfileJson` is set, uses that file
          directly. Otherwise generates a predefined profile from the syscall
          groups defined above.

          Returns a store path to the JSON file, suitable for use with
          `--security-opt seccomp=`.
        '';
        file = "nix/modules/oci/lib/mkSeccompProfile.nix";
        fn =
          {
            name,
            hardening,
          }:
          pure.mkSeccompProfile { inherit name hardening pkgs; };
      };
    };
}
