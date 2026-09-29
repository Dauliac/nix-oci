# BDD test specs for the trivy compliance (CIS) pipeline step.
#
# trivy compliance runs in the pre-push phase against a compliance
# spec (default `docker-cis-1.6.0`). Report format defaults to
# `summary`. The step surfaces as `oci-compliance-trivy-<container>`.
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * compliance-trivy CIS check runs
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.pipeline-compliance-trivy = {
        eval-defaults = {
          given = "a container with default compliance.trivy settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-compliance-enabled = {
          given = "a container with compliance.trivy.enabled = true";
          "when" = "the pipeline composer wires the pre-push compliance step";
          "then" = "the container package builds and exposes the compliance script";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            compliance.trivy = {
              enabled = true;
              spec = "docker-cis-1.6.0";
              report = "summary";
            };
          };
        };

        build-compliance-summary-report = {
          given = "a container with compliance summary report";
          "when" = "the compliance app runs against the image";
          "then" = "the emitted summary references at least one CIS control id";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = false;
            compliance.trivy = {
              enabled = true;
              spec = "docker-cis-1.6.0";
              report = "summary";
            };
          };
        };

        build-compliance-all-report = {
          given = "a container requesting the detailed compliance report";
          "when" = "the compliance app runs";
          "then" = "the emitted report is the full detail form rather than the summary";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            compliance.trivy = {
              enabled = true;
              spec = "docker-cis-1.6.0";
              report = "all";
            };
          };
        };
      };
    };
}
