# BDD test specs for container-probe end-to-end delivery.
#
# Bead: docs-ci-deploy-z83.4.4
# Spec: openspec/changes/runtime-behavioral-test-coverage/specs/testing/
#       runtime-behavior-verification/spec.md
#       Requirement "Container probes SHALL prove end-to-end delivery"
#
# Each of the four probes (amicontained, CDK, DEEPCE, linPEAS) has a
# runtime-level scenario that:
#   1. Builds a container with the probe opted in via test.<probe>.enabled
#   2. When the harness executes the corresponding `oci-<probe>-<name>`
#      app (synthesized in test-apps.nix per D7), the app exits 0 and
#      the captured stdout contains the tool's signature banner.
#
# The escape-hatch `runtime` field carries a Python snippet that the
# harness lifts into pytest against the docker SDK; it inspects the last
# report file in NIX_OCI_REPORT_DIR and greps for the tool banner. This
# lets the four probes participate in the same VM run that already boots
# the BDD suite; no separate harness is needed.
#
# When probe-app synthesis lands (agent A commit b8e6828), the
# oci-<probe>-<name> apps are added to test-apps.nix and CI wires each
# app to its scenario. Until then this file still surfaces the four BDD
# rows in the coverage docs and the scenarios evaluate cleanly.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.probes-e2e = {
        amicontained-emits-report = {
          given = "a container opting in via test.amicontained.enabled = true";
          "when" = "the oci-amicontained-<name> app runs against the loaded image";
          "then" = "the app exits 0 and the report contains \"Container Runtime:\" and \"Has Namespaces:\"";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.hello;
            test.amicontained.enabled = true;
          };
          # Escape-hatch: greps NIX_OCI_REPORT_DIR for the amicontained
          # signature banner. The harness sets NIX_OCI_REPORT_DIR to a
          # per-run tmpdir before invoking the probe app.
          assertions.runtime = ''
            import os, glob
            report_dir = os.environ.get("NIX_OCI_REPORT_DIR", "/tmp/nix-oci-reports")
            reports = sorted(glob.glob(os.path.join(report_dir, "*amicontained*")))
            assert reports, f"no amicontained report under {report_dir}"
            body = open(reports[-1]).read()
            assert "Container Runtime:" in body, (
                f"amicontained report missing 'Container Runtime:' section: {body[:400]}"
            )
            assert "Has Namespaces:" in body, (
                f"amicontained report missing 'Has Namespaces:' section: {body[:400]}"
            )
          '';
        };

        cdk-emits-report = {
          given = "a container opting in via test.cdk.enabled = true";
          "when" = "the oci-cdk-<name> app runs against the loaded image";
          "then" = "the app exits 0 and the report contains the CDK evaluate banner";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.hello;
            test.cdk.enabled = true;
          };
          assertions.runtime = ''
            import os, glob
            report_dir = os.environ.get("NIX_OCI_REPORT_DIR", "/tmp/nix-oci-reports")
            reports = sorted(glob.glob(os.path.join(report_dir, "*cdk*")))
            assert reports, f"no cdk report under {report_dir}"
            body = open(reports[-1]).read()
            # CDK prints its banner on every run; accept either the
            # "Container DIY Kit" title or the "evaluate" subcommand hint.
            assert ("CDK" in body) or ("evaluate" in body.lower()), (
                f"cdk report missing signature banner: {body[:400]}"
            )
          '';
        };

        deepce-emits-report = {
          given = "a container opting in via test.deepce.enabled = true";
          "when" = "the oci-deepce-<name> app runs against the loaded image";
          "then" = "the app exits 0 and NIX_OCI_REPORT_DIR contains a DEEPCE report";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.hello;
            test.deepce.enabled = true;
          };
          assertions.runtime = ''
            import os, glob
            report_dir = os.environ.get("NIX_OCI_REPORT_DIR", "/tmp/nix-oci-reports")
            reports = sorted(glob.glob(os.path.join(report_dir, "*deepce*")))
            assert reports, f"no deepce report under {report_dir}"
            body = open(reports[-1]).read()
            # DEEPCE emits its ASCII banner near the top of every run.
            assert "DEEPCE" in body.upper(), (
                f"deepce report missing 'DEEPCE' banner: {body[:400]}"
            )
          '';
        };

        linpeas-emits-report = {
          given = "a container opting in via test.linpeas.enabled = true";
          "when" = "the oci-linpeas-<name> app runs against the loaded image";
          "then" = "the app exits 0 and the report contains the linPEAS 'Basic information' header";
          level = "runtime";
          target = "oci";
          container = {
            package = pkgs.hello;
            test.linpeas.enabled = true;
          };
          assertions.runtime = ''
            import os, glob
            report_dir = os.environ.get("NIX_OCI_REPORT_DIR", "/tmp/nix-oci-reports")
            reports = sorted(glob.glob(os.path.join(report_dir, "*linpeas*")))
            assert reports, f"no linpeas report under {report_dir}"
            body = open(reports[-1]).read()
            assert "Basic information" in body, (
                f"linpeas report missing 'Basic information' header: {body[:400]}"
            )
          '';
        };
      };
    };
}
