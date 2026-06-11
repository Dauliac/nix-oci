"""Shared pytest fixtures for option-level container tests.

Uses the docker SDK (compatible with podman's Docker-compatible socket)
for structured container lifecycle management with proper wait/retry.
"""

import json
import os
import tarfile
import io

import docker
import pytest


@pytest.fixture(scope="session")
def client():
    """Docker SDK client via DOCKER_HOST or podman socket fallback."""
    host = os.environ.get("DOCKER_HOST")
    if host:
        return docker.DockerClient(base_url=host)
    # Fallback: try standard podman socket locations
    for sock in [
        "/run/podman/podman.sock",
        "/var/run/docker.sock",
    ]:
        if os.path.exists(sock):
            return docker.DockerClient(base_url=f"unix://{sock}")
    # Last resort
    return docker.from_env()


# ── Image-level helpers ───────────────────────────────────────────


class ImageHelper:
    """Assertions on OCI image metadata (no container runtime needed)."""

    def __init__(self, client, image_ref):
        self.client = client
        self.image_ref = image_ref
        self._image = None
        self._inspect = None

    @property
    def image(self):
        if self._image is None:
            self._image = self.client.images.get(self.image_ref)
        return self._image

    @property
    def inspect(self):
        if self._inspect is None:
            # Low-level API gives full inspect data
            self._inspect = self.client.api.inspect_image(self.image_ref)
        return self._inspect

    @property
    def config(self):
        return self.inspect.get("Config", {})

    @property
    def labels(self):
        return self.config.get("Labels", {})

    def assert_config(self, expected):
        """Assert OCI image Config fields match expected values.

        For dict values (Labels, ExposedPorts, Volumes), checks that
        expected is a SUBSET of actual (auto-labels add extra entries).
        For other types, checks exact equality.
        """
        for key, value in expected.items():
            actual = self.config.get(key)
            if isinstance(value, dict) and isinstance(actual, dict):
                for k, v in value.items():
                    assert k in actual, (
                        f"Image {self.image_ref}: expected Config.{key} to "
                        f"contain {k!r}={v!r}, got keys: {list(actual.keys())}"
                    )
                    assert actual[k] == v, (
                        f"Image {self.image_ref}: expected Config.{key}.{k}={v!r}, "
                        f"got: {actual[k]!r}"
                    )
            else:
                assert actual == value, (
                    f"Image {self.image_ref}: expected Config.{key}={value!r}, "
                    f"got: {actual!r}"
                )

    def assert_labels(self, expected):
        """Assert OCI labels match expected values."""
        for key, value in expected.items():
            actual = self.labels.get(key)
            assert actual == value, (
                f"Image {self.image_ref}: expected label {key}={value!r}, "
                f"got: {actual!r}"
            )

    def read_file(self, path):
        """Read a file from the image filesystem.

        Creates a temporary container (never started) and copies
        the file out. This reads from image layers directly,
        bypassing runtime bind-mounts.
        """
        container = self.client.containers.create(self.image_ref, command="true")
        try:
            bits, _ = container.get_archive(path)
            # get_archive returns a tar stream
            tar_bytes = b"".join(bits)
            with tarfile.open(fileobj=io.BytesIO(tar_bytes)) as tar:
                member = tar.getmembers()[0]
                f = tar.extractfile(member)
                return f.read().decode("utf-8", errors="replace") if f else ""
        finally:
            container.remove(force=True)

    def assert_file_contains(self, path, expected):
        """Assert a file inside the image contains a string."""
        content = self.read_file(path)
        assert expected in content, (
            f"Image {self.image_ref}: expected {path!r} to contain "
            f"{expected!r}, got: {content[:300]}"
        )

    def assert_file_not_contains(self, path, excluded):
        """Assert a file inside the image does NOT contain a string."""
        content = self.read_file(path)
        assert excluded not in content, (
            f"Image {self.image_ref}: expected {path!r} to NOT contain "
            f"{excluded!r}, got: {content[:300]}"
        )


# ── Container-level helpers ───────────────────────────────────────


class ContainerRunner:
    """Run and assert on containers using docker SDK."""

    def __init__(self, client, image_ref):
        self.client = client
        self.image_ref = image_ref

    def run_succeeds(self, command, args="", stdout=None):
        """Run a command in a throwaway container, assert exit 0."""
        full_cmd = f"{args}" if args else None
        result = self.client.containers.run(
            self.image_ref,
            command=full_cmd,
            entrypoint=command,
            remove=True,
        )
        output = result.decode("utf-8", errors="replace") if isinstance(result, bytes) else str(result)
        if stdout:
            assert stdout in output, (
                f"Image {self.image_ref}: expected {stdout!r} in output "
                f"of '{command} {args}', got: {output[:300]}"
            )
        return output

    def run_fails(self, command, args="", exit_code=None):
        """Run a command in a throwaway container, assert exit != 0."""
        full_cmd = f"{args}" if args else None
        try:
            self.client.containers.run(
                self.image_ref,
                command=full_cmd,
                entrypoint=command,
                remove=True,
            )
            pytest.fail(
                f"Image {self.image_ref}: expected '{command} {args}' "
                f"to fail, but it succeeded"
            )
        except docker.errors.ContainerError as e:
            if exit_code is not None:
                assert e.exit_status == exit_code, (
                    f"Image {self.image_ref}: expected exit code {exit_code} "
                    f"from '{command}', got: {e.exit_status}"
                )


# ── Daemon helpers ────────────────────────────────────────────────


class DaemonHelper:
    """Manage and assert on long-running daemon containers."""

    def __init__(self, client, container_name, image_ref):
        self.client = client
        self.name = container_name
        self.image_ref = image_ref
        self._container = None

    @property
    def container(self):
        if self._container is None:
            self._container = self.client.containers.get(self.name)
        return self._container

    def reload(self):
        """Refresh container state from daemon."""
        self._container = None
        return self.container

    def assert_env(self, key, contains):
        """Assert a process env var contains a string.

        Reads from /proc/1/environ for OCI-configured env vars.
        """
        exit_code, output = self.container.exec_run("cat /proc/1/environ")
        assert exit_code == 0, f"Failed to read /proc/1/environ: {output}"
        env_str = output.decode("utf-8", errors="replace").replace("\x00", "\n")
        matching = [l for l in env_str.strip().split("\n") if l.startswith(f"{key}=")]
        assert matching, f"Container {self.name}: env var {key} not found"
        assert contains in matching[0], (
            f"Container {self.name}: expected {key} to contain "
            f"{contains!r}, got: {matching[0]!r}"
        )

    def assert_inspect(self, expected):
        """Assert podman/docker inspect fields match (dot-path notation)."""
        data = self.client.api.inspect_container(self.name)
        for path, value in expected.items():
            actual = data
            for part in path.split("."):
                actual = actual.get(part, {}) if isinstance(actual, dict) else None
            assert actual == value, (
                f"Container {self.name}: expected inspect "
                f"{path}={value!r}, got: {actual!r}"
            )

    def exec_succeeds(self, command, stdout=None):
        """Run a command inside the running container, assert exit 0."""
        exit_code, output = self.container.exec_run(command)
        decoded = output.decode("utf-8", errors="replace")
        assert exit_code == 0, (
            f"Container {self.name}: exec '{command}' failed with "
            f"code {exit_code}: {decoded[:300]}"
        )
        if stdout:
            assert stdout in decoded, (
                f"Container {self.name}: expected {stdout!r} in exec "
                f"output of '{command}', got: {decoded[:300]}"
            )
        return decoded

    def exec_fails(self, command, exit_code=None):
        """Assert a command fails inside the running container."""
        code, output = self.container.exec_run(command)
        assert code != 0, f"Container {self.name}: expected exec '{command}' to fail"
        if exit_code is not None:
            assert code == exit_code, (
                f"Container {self.name}: expected exit code {exit_code} "
                f"from exec '{command}', got: {code}"
            )

    def stop(self, timeout=10):
        """Stop the container."""
        self.container.stop(timeout=timeout)

    def logs(self):
        """Return container logs as string."""
        return self.container.logs().decode("utf-8", errors="replace")


# ── Fixture factories ─────────────────────────────────────────────


@pytest.fixture(scope="session")
def image_helper(client):
    """Factory fixture: image_helper("my-image:latest") → ImageHelper."""
    def _make(image_ref):
        return ImageHelper(client, image_ref)
    return _make


@pytest.fixture(scope="session")
def container_runner(client):
    """Factory fixture: container_runner("my-image:latest") → ContainerRunner."""
    def _make(image_ref):
        return ContainerRunner(client, image_ref)
    return _make


@pytest.fixture(scope="session")
def daemon_helper(client):
    """Factory fixture: daemon_helper("name", "image:tag") → DaemonHelper."""
    def _make(container_name, image_ref):
        return DaemonHelper(client, container_name, image_ref)
    return _make
