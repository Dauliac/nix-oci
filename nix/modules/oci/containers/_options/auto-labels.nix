# Shared: automatic OCI label generation toggle.
{ lib, ... }:
{
  options.autoLabels = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether to automatically generate OCI image labels from package metadata.

      When enabled, the following labels are generated (user labels always override):
      - OCI standard annotations (`org.opencontainers.image.*`): title, version,
        description, licenses, base.name
      - Build info (`io.github.dauliac.nix-oci.build.*`): system, optimized-layers,
        reproducible
      - Hardening hints (`io.github.dauliac.nix-oci.hardening.*`): security posture
      - Kubernetes PSS level (`io.github.dauliac.nix-oci.kubernetes.pod-security-standard`)
    '';
  };
}
