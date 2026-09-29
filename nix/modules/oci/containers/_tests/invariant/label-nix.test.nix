# BDD spec for Nix identity label coherence (z83.7.17).
#
# Covers spec `Requirement: Nix identity label coherence`:
#   nix.pname, nix.version, nix.main-program, nix.dependency-count
#   labels reflect the container's package metadata and declared
#   dependencies.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.invariant-label-nix = {
        inspect-package-identity = {
          given = "a container built from pkgs.hello";
          "when" = "the OCI image is inspected";
          "then" = "nix.pname / nix.version / nix.main-program labels are present";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.nix.pname" = "hello";
            "io.github.dauliac.nix-oci.nix.version" = pkgs.hello.version;
            "io.github.dauliac.nix-oci.nix.main-program" = "hello";
          };
        };

        inspect-dependency-count = {
          given = "a container with three declared dependencies";
          "when" = "the OCI image is inspected";
          "then" = "nix.dependency-count = 3";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            dependencies = [
              pkgs.coreutils
              pkgs.bash
              pkgs.jq
            ];
          };
          assertions.imageConfig.Labels = {
            "io.github.dauliac.nix-oci.nix.dependency-count" = "3";
          };
        };
      };
    };
}
