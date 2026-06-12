"""Shared fixtures for non-hermetic E2E tests.

These tests run against the host's container daemon and nix daemon.
They replace the bats E2E suites with pytest parametrization.

Expects environment variables set by the Taskfile:
  NIX_OCI_APPS_JSON   — JSON array of flake app names
  NIX_OCI_PKGS_JSON   — JSON array of flake package names
  NIX_OCI_FLAKE_REF   — Flake reference (e.g., git+file:///path/to/repo)
  NIX_OCI_SYSTEM      — System string (e.g., x86_64-linux)
"""

import json
import os
import platform
import subprocess

import pytest


# -- Environment -------------------------------------------------------------


def _env(key):
    val = os.environ.get(key)
    if not val:
        pytest.skip(f"{key} not set (run via 'task test:e2e')")
    return val


@pytest.fixture(scope="session")
def flake_ref():
    return _env("NIX_OCI_FLAKE_REF")


@pytest.fixture(scope="session")
def apps_json():
    return json.loads(_env("NIX_OCI_APPS_JSON"))


@pytest.fixture(scope="session")
def pkgs_json():
    return json.loads(_env("NIX_OCI_PKGS_JSON"))


@pytest.fixture(scope="session")
def current_arch():
    machine = platform.machine()
    return {"x86_64": "amd64", "aarch64": "arm64"}.get(machine, "unknown")


# -- App discovery helpers ---------------------------------------------------


def apps_for_prefix(prefix):
    """Return app names matching a prefix from NIX_OCI_APPS_JSON.

    Used at module scope for pytest.mark.parametrize (evaluated at
    collection time, before fixtures run).
    """
    raw = os.environ.get("NIX_OCI_APPS_JSON", "[]")
    return [a for a in json.loads(raw) if a.startswith(prefix)]


def pkgs_for_prefix(prefix):
    """Return package names matching a prefix from NIX_OCI_PKGS_JSON."""
    raw = os.environ.get("NIX_OCI_PKGS_JSON", "[]")
    return [p for p in json.loads(raw) if p.startswith(prefix)]


# -- Nix run helper ----------------------------------------------------------


def nix_run(flake_ref, app, timeout=600):
    """Run a flake app and return the CompletedProcess."""
    return subprocess.run(
        ["nix", "run", f"{flake_ref}#{app}"],
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def nix_build(flake_ref, attr, timeout=600):
    """Build a flake attribute and return the store path."""
    result = subprocess.run(
        ["nix", "build", f"{flake_ref}#{attr}", "--no-link", "--print-out-paths"],
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    assert result.returncode == 0, (
        f"nix build {attr} failed:\n{result.stderr}"
    )
    # Extract /nix/store path (nix may emit warnings before it)
    for line in result.stdout.strip().split("\n"):
        if line.startswith("/nix/store/"):
            return line.strip()
    pytest.fail(f"No store path in nix build output:\n{result.stdout}")
