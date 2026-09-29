# BDD test specs for the syft SBOM pipeline step.
#
# Verifies that with sbom.syft.enabled = true, the gate produces a
# CycloneDX JSON document (surfaced as $out/sbom.cdx.json by the
# pipeline composer) containing the packages actually shipped in the
# container closure.
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * syft SBOM is a valid CycloneDX document
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.pipeline-syft = {
        eval-defaults = {
          given = "a container with default sbom.syft settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-syft-enabled-for-hello = {
          given = "a container built from pkgs.hello with syft SBOM enabled";
          "when" = "the gate is built";
          "then" = "the syft stamp materialises a CycloneDX JSON referencing hello";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            sbom.syft.enabled = true;
          };
        };

        build-syft-parses-as-cyclonedx = {
          given = "a container with syft SBOM enabled";
          "when" = "the emitted SBOM JSON is parsed";
          "then" = "it is a valid CycloneDX document with at least one component entry";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = false;
            sbom.syft.enabled = true;
          };
        };
      };
    };
}
