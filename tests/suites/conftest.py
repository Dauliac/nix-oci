"""Shared pytest fixtures for VM integration test suites.

Uses the Docker SDK (via podman's Docker-compatible socket).
Self-contained: designed to be copied into a test derivation for in-VM execution.
"""

import io
import json
import os
import subprocess
import tarfile
import time

import docker
import pytest


# -- Docker client -----------------------------------------------------------


@pytest.fixture(scope="session")
def client():
    """Docker SDK client via DOCKER_HOST or podman socket fallback."""
    host = os.environ.get("DOCKER_HOST")
    if host:
        return docker.DockerClient(base_url=host)
    for sock in ["/run/podman/podman.sock", "/var/run/docker.sock"]:
        if os.path.exists(sock):
            return docker.DockerClient(base_url=f"unix://{sock}")
    return docker.from_env()


@pytest.fixture(scope="session")
def backend():
    """Test backend: 'nixos' or 'system-manager'."""
    return os.environ.get("TEST_BACKEND", "nixos")


@pytest.fixture(scope="session")
def nixos_only(backend):
    """Skip the test unless running on the NixOS backend."""
    if backend != "nixos":
        pytest.skip("NixOS-only test")


# -- Image helper ------------------------------------------------------------


class ImageHelper:
    """Assertions on OCI image metadata (no container runtime needed)."""

    def __init__(self, client, image_ref):
        self.client = client
        self.image_ref = image_ref
        self._inspect = None

    @property
    def inspect(self):
        if self._inspect is None:
            self._inspect = self.client.api.inspect_image(self.image_ref)
        return self._inspect

    @property
    def config(self):
        return self.inspect.get("Config", {})

    @property
    def labels(self):
        return self.config.get("Labels", {})

    @property
    def env_dict(self):
        env_list = self.config.get("Env", [])
        d = {}
        for entry in env_list:
            k, _, v = entry.partition("=")
            d[k] = v
        return d

    def assert_user(self, expected):
        actual = self.config.get("User", "")
        assert actual == expected, (
            f"{self.image_ref}: expected User={expected!r}, got {actual!r}"
        )

    def assert_labels(self, expected):
        for key, value in expected.items():
            actual = self.labels.get(key)
            assert actual == value, (
                f"{self.image_ref}: expected label {key}={value!r}, got {actual!r}"
            )

    def assert_env(self, key, value):
        env = self.env_dict
        assert key in env, f"{self.image_ref}: env {key} not found in {list(env)}"
        assert env[key] == value, (
            f"{self.image_ref}: expected {key}={value!r}, got {env[key]!r}"
        )

    def assert_env_exists(self, key):
        env = self.env_dict
        assert key in env, (
            f"{self.image_ref}: expected env var {key}, got keys: {list(env)}"
        )

    def read_file(self, path):
        """Read a file from the image filesystem via docker cp."""
        container = self.client.containers.create(self.image_ref, command="true")
        try:
            bits, _ = container.get_archive(path)
            tar_bytes = b"".join(bits)
            with tarfile.open(fileobj=io.BytesIO(tar_bytes)) as tar:
                member = tar.getmembers()[0]
                f = tar.extractfile(member)
                return f.read().decode("utf-8", errors="replace") if f else ""
        finally:
            container.remove(force=True)

    def assert_file_contains(self, path, expected):
        content = self.read_file(path)
        assert expected in content, (
            f"{self.image_ref}: expected {path!r} to contain "
            f"{expected!r}, got: {content[:300]}"
        )

    def assert_file_not_contains(self, path, excluded):
        content = self.read_file(path)
        assert excluded not in content, (
            f"{self.image_ref}: expected {path!r} to NOT contain {excluded!r}"
        )


@pytest.fixture(scope="session")
def image_helper(client):
    """Factory: image_helper("my-image:latest") -> ImageHelper."""

    def _make(image_ref):
        return ImageHelper(client, image_ref)

    return _make


# -- Container run helper ----------------------------------------------------


@pytest.fixture(scope="session")
def run_container(client):
    """Run a one-shot container and return decoded stdout."""

    def _run(image_ref, entrypoint, args=""):
        result = client.containers.run(
            image_ref,
            entrypoint=entrypoint,
            command=args if args else None,
            remove=True,
        )
        return (
            result.decode("utf-8", errors="replace")
            if isinstance(result, bytes)
            else str(result)
        )

    return _run


# -- Systemd helpers ---------------------------------------------------------


class SystemdHelper:
    """Query and assert on systemd unit properties."""

    @staticmethod
    def show(unit, *properties, user=None):
        cmd = ["systemctl"]
        env = None
        if user:
            cmd.append("--user")
            env = {**os.environ, "XDG_RUNTIME_DIR": f"/run/user/{os.getuid()}"}
        cmd.extend(["show", unit, f"--property={','.join(properties)}"])
        result = subprocess.run(cmd, capture_output=True, text=True, env=env)
        assert result.returncode == 0, f"Failed to query {unit}: {result.stderr}"
        return result.stdout

    @staticmethod
    def assert_props(unit, expected, user=None):
        props = SystemdHelper.show(unit, *expected.keys(), user=user)
        for key, value in expected.items():
            assert f"{key}={value}" in props, (
                f"{unit}: expected {key}={value}, got: {props}"
            )

    @staticmethod
    def assert_active(unit, user=None):
        SystemdHelper.assert_props(unit, {"ActiveState": "active"}, user=user)

    @staticmethod
    def assert_depends_on(unit, dependency, user=None):
        props = SystemdHelper.show(unit, "After", "Requires", user=user)
        assert dependency in props, (
            f"{unit} must depend on {dependency}: {props}"
        )


@pytest.fixture(scope="session")
def systemd():
    """Access to SystemdHelper methods."""
    return SystemdHelper


# -- HTTP helpers ------------------------------------------------------------


def wait_http(url, timeout=30, interval=1):
    """Poll an HTTP URL until it responds 2xx."""
    import requests

    deadline = time.time() + timeout
    last_err = None
    while time.time() < deadline:
        try:
            resp = requests.get(url, timeout=5)
            resp.raise_for_status()
            return resp
        except Exception as e:
            last_err = e
            time.sleep(interval)
    raise TimeoutError(f"{url} did not respond within {timeout}s: {last_err}")
