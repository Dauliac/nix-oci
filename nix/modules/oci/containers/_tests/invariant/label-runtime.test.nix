# BDD spec for runtime info label coherence (z83.7.16).
#
# Covers spec `Requirement: Runtime info label coherence`:
#   runtime.user and runtime.is-root labels match isRoot.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-label-runtime = {
        inspect-non-root-runtime = {
          given = "a container with isRoot=false";
          "when" = "the OCI image is inspected";
          "then" = "runtime.user=non-root and runtime.is-root=false";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.runtime.user" = "non-root";
            "io.github.dauliac.nix-oci.runtime.is-root" = "false";
          };
        };

        inspect-root-runtime = {
          given = "a container with isRoot=true";
          "when" = "the OCI image is inspected";
          "then" = "runtime.user=root and runtime.is-root=true";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.runtime.user" = "root";
            "io.github.dauliac.nix-oci.runtime.is-root" = "true";
          };
        };
      };
    };
}
