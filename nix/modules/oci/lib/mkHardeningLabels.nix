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
  ns = "io.github.dauliac.nix-oci";
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
        fn =
          { hardening }:
          lib.optionalAttrs hardening.enable (
            {
              "${ns}.hardening.enabled" = "true";
              "${ns}.hardening.no-new-privileges" = lib.boolToString hardening.noNewPrivileges;
              "${ns}.hardening.read-only-rootfs" = lib.boolToString hardening.readOnlyRootfs;
              "${ns}.hardening.capabilities-drop" = lib.concatStringsSep "," hardening.capabilities.drop;
            }
            // lib.optionalAttrs (hardening.capabilities.add != [ ]) {
              "${ns}.hardening.capabilities-add" = lib.concatStringsSep "," hardening.capabilities.add;
            }
            // lib.optionalAttrs hardening.seccomp.enable {
              "${ns}.hardening.seccomp-profile" = hardening.seccomp.profile;
            }
            // lib.optionalAttrs hardening.landlock.enable {
              "${ns}.hardening.landlock-enabled" = "true";
            }
          );
      };
    };
}
