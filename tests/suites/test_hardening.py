"""Hardening tests -- seccomp, capabilities, DNS, TLS, labels."""

import docker
import pytest

NS = "io.github.dauliac.nix-oci"


class TestHardeningDnsDisabled:
    IMAGE = "hardening-dns-disabled:latest"

    def test_hardening_labels(self, image_helper):
        image_helper(self.IMAGE).assert_labels(
            {
                f"{NS}.hardening.enabled": "true",
                f"{NS}.hardening.dns-disabled": "true",
            }
        )

    def test_nsswitch_no_dns_backend(self, image_helper):
        content = image_helper(self.IMAGE).read_file("/etc/nsswitch.conf")
        assert "hosts:" in content
        for line in content.splitlines():
            if line.startswith("hosts:"):
                assert " dns" not in line.split("#")[0], (
                    f"hosts line should not contain dns: {line}"
                )

    def test_busybox_runs(self, run_container):
        run_container(self.IMAGE, "/bin/busybox", "--help")


class TestHardeningNoTls:
    IMAGE = "hardening-no-tls:latest"

    def test_hardening_labels(self, image_helper):
        image_helper(self.IMAGE).assert_labels(
            {
                f"{NS}.hardening.enabled": "true",
                f"{NS}.hardening.tls-trust-store-removed": "true",
            }
        )

    def test_ca_bundle_has_removal_marker(self, image_helper):
        image_helper(self.IMAGE).assert_file_contains(
            "/etc/ssl/certs/ca-bundle.crt",
            "TLS trust store removed by nix-oci hardening",
        )

    def test_ca_bundle_no_real_certificates(self, image_helper):
        image_helper(self.IMAGE).assert_file_not_contains(
            "/etc/ssl/certs/ca-bundle.crt",
            "BEGIN CERTIFICATE",
        )

    def test_busybox_runs(self, run_container):
        run_container(self.IMAGE, "/bin/busybox", "--help")


class TestHardeningFull:
    IMAGE = "hardening-full:latest"

    def test_all_hardening_labels(self, image_helper):
        image_helper(self.IMAGE).assert_labels(
            {
                f"{NS}.hardening.enabled": "true",
                f"{NS}.hardening.no-new-privileges": "true",
                f"{NS}.hardening.read-only-rootfs": "true",
                f"{NS}.hardening.capabilities-drop": "ALL",
                f"{NS}.hardening.capabilities-add": "NET_BIND_SERVICE",
                f"{NS}.hardening.seccomp-profile": "strict",
                f"{NS}.hardening.dns-disabled": "true",
                f"{NS}.hardening.tls-trust-store-removed": "true",
            }
        )

    def test_nsswitch_no_dns(self, image_helper):
        content = image_helper(self.IMAGE).read_file("/etc/nsswitch.conf")
        for line in content.splitlines():
            if line.startswith("hosts:"):
                assert " dns" not in line.split("#")[0]

    def test_tls_ca_bundle_neutered(self, image_helper):
        image_helper(self.IMAGE).assert_file_contains(
            "/etc/ssl/certs/ca-bundle.crt",
            "TLS trust store removed by nix-oci hardening",
        )

    def test_no_real_certificates(self, image_helper):
        image_helper(self.IMAGE).assert_file_not_contains(
            "/etc/ssl/certs/ca-bundle.crt",
            "BEGIN CERTIFICATE",
        )

    def test_busybox_runs(self, run_container):
        run_container(self.IMAGE, "/bin/busybox", "--help")

    def test_passwd_has_entries(self, image_helper):
        content = image_helper(self.IMAGE).read_file("/etc/passwd")
        lines = [line for line in content.splitlines() if line.strip()]
        assert len(lines) > 0, "passwd should have entries"


class TestHardeningSeccompEnforce:
    IMAGE = "hardening-seccomp-enforce:latest"

    def test_io_uring_setup_returns_eperm(self, client):
        """io_uring_setup syscall should be blocked by seccomp (exit 1)."""
        try:
            client.containers.run(
                self.IMAGE,
                entrypoint="/bin/try-io-uring",
                remove=True,
            )
            pytest.fail("Expected non-zero exit from try-io-uring")
        except docker.errors.ContainerError as e:
            assert e.exit_status == 1, (
                f"Expected exit code 1 (EPERM from seccomp), got {e.exit_status}"
            )

    def test_busybox_still_works(self, run_container):
        run_container(self.IMAGE, "/bin/busybox", "--help")


class TestHardeningDatabase:
    IMAGE = "hardening-database:latest"

    def test_seccomp_profile_label(self, image_helper):
        image_helper(self.IMAGE).assert_labels(
            {
                f"{NS}.hardening.seccomp-profile": "database",
                f"{NS}.hardening.enabled": "true",
            }
        )

    def test_busybox_runs(self, run_container):
        run_container(self.IMAGE, "/bin/busybox", "--help")


class TestHardeningAudit:
    IMAGE = "hardening-audit:latest"

    def test_seccomp_profile_label(self, image_helper):
        image_helper(self.IMAGE).assert_labels(
            {f"{NS}.hardening.seccomp-profile": "strict"}
        )

    def test_busybox_runs_not_blocked(self, run_container):
        """In audit mode, seccomp logs but does not block."""
        run_container(self.IMAGE, "/bin/busybox", "--help")
