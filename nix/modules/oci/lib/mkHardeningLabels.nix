# OCI mkHardeningLabels - Generate OCI labels from hardening config
#
# Embeds runtime security hints as OCI image labels under the
# `io.github.dauliac.nix-oci.hardening.*` namespace. Deploy modules read
# these labels and translate them to container runtime flags.
#
# NOTE: Prefer mkAutoLabels which includes hardening labels plus OCI standard
# annotations and build info. This function is kept for backward compatibility.
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci.mkHardeningLabels = {
        type = lib.types.functionTo lib.types.attrs;
        description = ''
          Generate OCI labels from hardening configuration.

          Embeds runtime hints as labels:
          - `io.github.dauliac.nix-oci.hardening.enabled`
          - `io.github.dauliac.nix-oci.hardening.no-new-privileges`
          - `io.github.dauliac.nix-oci.hardening.read-only-rootfs`
          - `io.github.dauliac.nix-oci.hardening.capabilities-drop`
          - `io.github.dauliac.nix-oci.hardening.capabilities-add`
          - `io.github.dauliac.nix-oci.hardening.seccomp-profile` (profile name)

          Deploy modules read these to apply the corresponding
          `--security-opt`, `--cap-drop`, `--cap-add`, `--read-only`
          flags at runtime.

          NOTE: Prefer mkAutoLabels for new code.
        '';
        file = "nix/lib/oci.nix";
        fn = pure.mkHardeningLabels;
        tests = {
          "generates labels when hardening enabled" = {
            args = {
              hardening = {
                enable = true;
                noNewPrivileges = true;
                readOnlyRootfs = true;
                capabilities = {
                  drop = [ "ALL" ];
                  add = [ ];
                };
                seccomp = {
                  enable = true;
                  profile = "strict";
                };
              };
            };
            assertions = [
              {
                name = "has enabled label";
                check = result: result."io.github.dauliac.nix-oci.hardening.enabled" == "true";
              }
              {
                name = "has seccomp profile label";
                check = result: result."io.github.dauliac.nix-oci.hardening.seccomp-profile" == "strict";
              }
              {
                name = "has capabilities-drop label";
                check = result: result."io.github.dauliac.nix-oci.hardening.capabilities-drop" == "ALL";
              }
            ];
          };
          "returns empty attrs when disabled" = {
            args = {
              hardening = {
                enable = false;
                noNewPrivileges = true;
                readOnlyRootfs = true;
                capabilities = {
                  drop = [ "ALL" ];
                  add = [ ];
                };
                seccomp.enable = false;
              };
            };
            expected = { };
          };
        };
      };
    };
}
