"""Deploy integration tests -- systemd lifecycle, HTTP, firewall, exec.

Basic deploy tests (http-server) run on both backends.
NixOS-specific tests (redis, dev-shell, home-manager) are skipped
on non-NixOS backends.
"""

import json
import os
import subprocess

import pytest

from conftest import SystemdHelper, wait_http


# -- Basic deploy (both backends) --------------------------------------------


class TestDeployHttpServer:
    """http-server container deploy lifecycle."""

    def test_load_service_lifecycle(self):
        props = SystemdHelper.show(
            "oci-load-http-server.service",
            "Type",
            "RemainAfterExit",
            "ActiveState",
        )
        assert "Type=oneshot" in props
        assert "RemainAfterExit=yes" in props
        assert "ActiveState=active" in props

    def test_container_service_starts(self):
        SystemdHelper.assert_active("podman-http-server.service")

    def test_runner_depends_on_loader(self):
        SystemdHelper.assert_depends_on(
            "podman-http-server.service",
            "oci-load-http-server.service",
        )

    def test_image_present(self, client):
        images = client.images.list()
        tags = [tag for img in images for tag in (img.tags or [])]
        assert any("http-server" in t for t in tags), (
            f"http-server image not found in {tags}"
        )

    def test_http_responds(self):
        resp = wait_http("http://localhost:8080/index.html")
        assert "nix-oci-test-ok" in resp.text

    def test_exec_works(self, client):
        containers = client.containers.list()
        for c in containers:
            if "http-server" in c.name:
                exit_code, output = c.exec_run("echo container-exec-ok")
                assert exit_code == 0, f"exec failed: {exit_code}"
                assert b"container-exec-ok" in output
                return
        pytest.fail("http-server container not found")


# -- NixOS-only deploy tests -------------------------------------------------


class TestDeployFirewall:
    """Firewall rules (NixOS iptables)."""

    @pytest.fixture(autouse=True)
    def _require_nixos(self, nixos_only):
        pass

    def test_firewall_allows_8080(self):
        result = subprocess.run(
            ["iptables", "-L", "nixos-fw", "-n"],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, f"iptables failed: {result.stderr}"
        assert "8080" in result.stdout, (
            f"Firewall should allow 8080: {result.stdout}"
        )

    def test_firewall_allows_6379(self):
        result = subprocess.run(
            ["iptables", "-L", "nixos-fw", "-n"],
            capture_output=True,
            text=True,
        )
        assert "6379" in result.stdout, (
            f"Firewall should allow 6379: {result.stdout}"
        )


class TestDeployRedis:
    """Redis deploy with nixosConfig.mainService + sdnotify."""

    @pytest.fixture(autouse=True)
    def _require_nixos(self, nixos_only):
        pass

    def test_load_and_start(self):
        SystemdHelper.assert_active("oci-load-redis.service")
        SystemdHelper.assert_active("podman-redis.service")
        SystemdHelper.assert_depends_on(
            "podman-redis.service", "oci-load-redis.service"
        )

    def test_redis_responds_to_ping(self):
        result = subprocess.run(
            ["redis-cli", "-h", "127.0.0.1", "-p", "6379", "ping"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert "PONG" in result.stdout, f"Expected PONG: {result.stdout}"

    def test_sdnotify_type_notify(self):
        SystemdHelper.assert_props(
            "podman-redis.service",
            {"Type": "notify", "NotifyAccess": "all"},
        )

    def test_stop_signal_sigterm(self, client):
        data = client.api.inspect_container("redis")
        sig = data.get("Config", {}).get("StopSignal", "")
        assert sig in ("SIGTERM", "15"), f"Expected SIGTERM: {sig}"


class TestDeployDevShell:
    """dev-shell container deploy (homeConfig in deploy)."""

    @pytest.fixture(autouse=True)
    def _require_nixos(self, nixos_only):
        pass

    def test_load_and_start(self):
        SystemdHelper.assert_active("oci-load-dev-shell.service")
        SystemdHelper.assert_active("podman-dev-shell.service")

    def test_exec_works(self, client):
        containers = client.containers.list()
        for c in containers:
            if "dev-shell" in c.name:
                exit_code, output = c.exec_run("echo dev-shell-ok")
                assert exit_code == 0
                assert b"dev-shell-ok" in output
                return
        pytest.fail("dev-shell container not found")

    def test_home_dev_exists(self, client):
        containers = client.containers.list()
        for c in containers:
            if "dev-shell" in c.name:
                exit_code, output = c.exec_run("ls -d /home/dev")
                assert exit_code == 0
                assert b"/home/dev" in output
                return
        pytest.fail("dev-shell container not found")


class TestDeployHomeManager:
    """Home-manager rootless podman deploy (testuser)."""

    USER = "testuser"

    @pytest.fixture(autouse=True)
    def _require_nixos(self, nixos_only):
        pass

    def test_load_service_lifecycle(self):
        SystemdHelper.assert_props(
            "oci-load-http-server.service",
            {"Type": "oneshot", "RemainAfterExit": "yes", "ActiveState": "active"},
            user=self.USER,
        )

    def test_runner_starts(self):
        SystemdHelper.assert_active(
            "podman-http-server.service", user=self.USER
        )

    def test_runner_depends_on_loader(self):
        SystemdHelper.assert_depends_on(
            "podman-http-server.service",
            "oci-load-http-server.service",
            user=self.USER,
        )

    def test_image_loaded(self):
        result = subprocess.run(
            ["podman", "images", "--format", "json"],
            capture_output=True,
            text=True,
            env={
                **os.environ,
                "XDG_RUNTIME_DIR": f"/run/user/{os.getuid()}",
            },
        )
        images = json.loads(result.stdout)
        names = []
        for img in images:
            for key in ("Names", "names", "RepoTags"):
                if key in img and img[key]:
                    names.extend(img[key])
        assert any("http-server" in n for n in names), (
            f"http-server not found in {names}"
        )

    def test_http_responds(self):
        resp = wait_http("http://localhost:9090/index.html")
        assert "nix-oci-test-ok" in resp.text
