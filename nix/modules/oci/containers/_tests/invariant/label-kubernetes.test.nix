# BDD spec for Kubernetes label coherence (z83.7.15).
#
# Covers spec `Requirement: Kubernetes label coherence`:
#   pod-security-standard, run-as-user/group, fs-group, and
#   seccomp-profile-type labels reflect the container's security
#   posture.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-label-kubernetes = {
        inspect-pss-restricted = {
          given = "a container satisfying all restricted-tier conditions";
          "when" = "the OCI image is inspected";
          "then" = "kubernetes.pod-security-standard = restricted";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            hardening = {
              enable = true;
              noNewPrivileges = true;
              readOnlyRootfs = true;
              capabilities.drop = [ "ALL" ];
              seccomp.enable = true;
            };
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.kubernetes.pod-security-standard" = "restricted";
            "io.github.dauliac.nix-oci.kubernetes.seccomp-profile-type" = "RuntimeDefault";
          };
        };

        inspect-run-as-user-non-root = {
          given = "a container with isRoot=false";
          "when" = "the OCI image is inspected";
          "then" = "kubernetes.run-as-user = 4000 and fs-group = 4000";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.kubernetes.run-as-user" = "4000";
            "io.github.dauliac.nix-oci.kubernetes.run-as-group" = "4000";
            "io.github.dauliac.nix-oci.kubernetes.fs-group" = "4000";
          };
        };

        inspect-run-as-user-root = {
          given = "a container with isRoot=true";
          "when" = "the OCI image is inspected";
          "then" = "kubernetes.run-as-user = 0";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.kubernetes.run-as-user" = "0";
          };
        };
      };
    };
}
