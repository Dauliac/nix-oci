"""Security and validation app tests (replaces main.bats + apps.bats).

Each app is a separate parametrized test case, auto-discovered from
the flake. Tests run ``nix run .#<app>`` and assert exit code 0.
"""

import pytest

from conftest import apps_for_prefix, nix_run


# -- Container Structure Tests -----------------------------------------------


CST_APPS = apps_for_prefix("oci-container-structure-test-")


@pytest.mark.skipif(not CST_APPS, reason="no CST apps discovered")
class TestContainerStructureTests:
    @pytest.mark.parametrize("app", CST_APPS, ids=CST_APPS)
    def test_cst_passes(self, flake_ref, app):
        result = nix_run(flake_ref, app)
        assert result.returncode == 0, (
            f"{app} failed:\nstdout: {result.stdout[-500:]}\n"
            f"stderr: {result.stderr[-500:]}"
        )


# -- CVE Scanners ------------------------------------------------------------


CVE_APPS = apps_for_prefix("oci-cve-")


@pytest.mark.skipif(not CVE_APPS, reason="no CVE apps discovered")
class TestCveScanners:
    @pytest.mark.parametrize("app", CVE_APPS, ids=CVE_APPS)
    def test_cve_scan_passes(self, flake_ref, app):
        result = nix_run(flake_ref, app)
        assert result.returncode == 0, (
            f"{app} failed:\nstdout: {result.stdout[-500:]}\n"
            f"stderr: {result.stderr[-500:]}"
        )


# -- Credentials Leak Scanners -----------------------------------------------


CRED_APPS = apps_for_prefix("oci-credentials-leak-")


@pytest.mark.skipif(not CRED_APPS, reason="no credentials-leak apps discovered")
class TestCredentialsLeakScanners:
    @pytest.mark.parametrize("app", CRED_APPS, ids=CRED_APPS)
    def test_credentials_leak_scan_passes(self, flake_ref, app):
        result = nix_run(flake_ref, app)
        assert result.returncode == 0, (
            f"{app} failed:\nstdout: {result.stdout[-500:]}\n"
            f"stderr: {result.stderr[-500:]}"
        )


# -- SBOM Generators ---------------------------------------------------------


SBOM_APPS = apps_for_prefix("oci-sbom-")


@pytest.mark.skipif(not SBOM_APPS, reason="no SBOM apps discovered")
class TestSbomGenerators:
    @pytest.mark.parametrize("app", SBOM_APPS, ids=SBOM_APPS)
    def test_sbom_generation_passes(self, flake_ref, app):
        result = nix_run(flake_ref, app)
        assert result.returncode == 0, (
            f"{app} failed:\nstdout: {result.stdout[-500:]}\n"
            f"stderr: {result.stderr[-500:]}"
        )


# -- Dgoss Tests -------------------------------------------------------------


DGOSS_APPS = apps_for_prefix("oci-dgoss-")


@pytest.mark.skipif(not DGOSS_APPS, reason="no dgoss apps discovered")
class TestDgoss:
    @pytest.mark.parametrize("app", DGOSS_APPS, ids=DGOSS_APPS)
    def test_dgoss_passes(self, flake_ref, app):
        result = nix_run(flake_ref, app)
        assert result.returncode == 0, (
            f"{app} failed:\nstdout: {result.stdout[-500:]}\n"
            f"stderr: {result.stderr[-500:]}"
        )


# -- Compliance Scanners -----------------------------------------------------


COMPLIANCE_APPS = apps_for_prefix("oci-compliance-")


@pytest.mark.skipif(not COMPLIANCE_APPS, reason="no compliance apps discovered")
class TestComplianceScanners:
    @pytest.mark.parametrize("app", COMPLIANCE_APPS, ids=COMPLIANCE_APPS)
    def test_compliance_scan_passes(self, flake_ref, app):
        result = nix_run(flake_ref, app)
        assert result.returncode == 0, (
            f"{app} failed:\nstdout: {result.stdout[-500:]}\n"
            f"stderr: {result.stderr[-500:]}"
        )


# -- Lint (Dockle) -----------------------------------------------------------


LINT_APPS = apps_for_prefix("oci-lint-")


@pytest.mark.skipif(not LINT_APPS, reason="no lint apps discovered")
class TestLint:
    @pytest.mark.parametrize("app", LINT_APPS, ids=LINT_APPS)
    def test_lint_passes(self, flake_ref, app):
        result = nix_run(flake_ref, app)
        assert result.returncode == 0, (
            f"{app} failed:\nstdout: {result.stdout[-500:]}\n"
            f"stderr: {result.stderr[-500:]}"
        )


# -- Policy (Conftest) -------------------------------------------------------


POLICY_APPS = apps_for_prefix("oci-policy-")


@pytest.mark.skipif(not POLICY_APPS, reason="no policy apps discovered")
class TestPolicy:
    @pytest.mark.parametrize("app", POLICY_APPS, ids=POLICY_APPS)
    def test_policy_passes(self, flake_ref, app):
        result = nix_run(flake_ref, app)
        assert result.returncode == 0, (
            f"{app} failed:\nstdout: {result.stdout[-500:]}\n"
            f"stderr: {result.stderr[-500:]}"
        )
