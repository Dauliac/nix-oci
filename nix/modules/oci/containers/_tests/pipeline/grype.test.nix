# BDD test specs for the grype CVE pipeline step.
#
# grype runs in the pre-push phase and is surfaced as
# `oci-cve-grype-<container>`. Enabling the step causes the pipeline
# composer to wire a script that emits a JSON report against the
# built image.
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * grype CVE scanner runs
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.pipeline-grype = {
        eval-defaults = {
          given = "a container with default cve.grype settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-grype-enabled = {
          given = "a container with cve.grype.enabled = true";
          "when" = "the pipeline composer wires the pre-push grype step";
          "then" = "the container package builds and exposes the grype script";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            cve.grype.enabled = true;
          };
        };

        build-grype-emits-report = {
          given = "a container with grype enabled and a set NIX_OCI_REPORT_DIR";
          "when" = "the grype app runs against the archive";
          "then" = "a JSON report is written to the report directory";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = false;
            cve.grype.enabled = true;
          };
        };
      };
    };
}
