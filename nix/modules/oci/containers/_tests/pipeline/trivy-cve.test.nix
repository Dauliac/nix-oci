# BDD test specs for the trivy CVE pipeline step.
#
# trivy CVE scanning runs in the pre-push phase (impure, needs the
# vulnerability DB) and surfaces as an `oci-cve-trivy-<container>`
# app. The step honours `cve.trivy.ignore.extra` for per-CVE
# suppression and writes a report to $NIX_OCI_REPORT_DIR when set.
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * trivy CVE scanner runs with ignore file
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.pipeline-trivy-cve = {
        eval-defaults = {
          given = "a container with default cve.trivy settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-trivy-cve-enabled = {
          given = "a container with trivy CVE scanning enabled";
          "when" = "the pipeline composer wires the pre-push step";
          "then" = "the container package builds and exposes the CVE script";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            cve.trivy.enabled = true;
          };
        };

        build-trivy-cve-ignore-extra = {
          given = "a container declaring cve.trivy.ignore.extra with a known CVE ID";
          "when" = "the pre-push app runs against the image";
          "then" = "the listed CVE is suppressed and the app exits 0";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            cve.trivy = {
              enabled = true;
              ignore = {
                fileEnabled = true;
                extra = [
                  "CVE-2023-0000"
                  "CVE-2024-0001"
                ];
              };
            };
          };
        };

        build-trivy-cve-report-dir = {
          given = "a container with trivy enabled and NIX_OCI_REPORT_DIR set at run time";
          "when" = "the pre-push scan runs";
          "then" = "the trivy report is written into the report directory";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            cve.trivy.enabled = true;
          };
        };
      };
    };
}
