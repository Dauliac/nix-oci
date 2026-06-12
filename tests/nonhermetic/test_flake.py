"""Flake health and template tests (replaces misc tests from main.bats)."""

import os
import subprocess
import tempfile

import pytest

from conftest import nix_run


class TestFlakeHealth:
    def test_flake_show_works(self, flake_ref):
        result = subprocess.run(
            ["nix", "flake", "show", flake_ref],
            capture_output=True,
            text=True,
            timeout=120,
        )
        assert result.returncode == 0, (
            f"nix flake show failed:\n{result.stderr[-500:]}"
        )

    def test_update_pulled_manifests_locks(self, flake_ref):
        result = nix_run(flake_ref, "oci-updatePulledManifestsLocks")
        assert result.returncode == 0, (
            f"updatePulledManifestsLocks failed:\n{result.stderr[-500:]}"
        )


class TestFlakeTemplate:
    def test_default_template_works(self, flake_ref):
        """Init a fresh repo with the default template, verify flake show."""
        repo_root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
        ).stdout.strip()

        with tempfile.TemporaryDirectory() as tmpdir:
            subprocess.run(
                ["git", "init", "-b", "main"],
                cwd=tmpdir,
                capture_output=True,
                check=True,
            )
            result = subprocess.run(
                ["nix", "flake", "init", "-t", repo_root],
                cwd=tmpdir,
                capture_output=True,
                text=True,
                timeout=120,
            )
            assert result.returncode == 0, (
                f"flake init failed:\n{result.stderr[-500:]}"
            )

            subprocess.run(
                ["git", "add", "."],
                cwd=tmpdir,
                capture_output=True,
                check=True,
            )
            result = subprocess.run(
                [
                    "nix",
                    "flake",
                    "show",
                    "--override-input",
                    "nix-oci",
                    f"path:{repo_root}",
                ],
                cwd=tmpdir,
                capture_output=True,
                text=True,
                timeout=120,
            )
            assert result.returncode == 0, (
                f"flake show on template failed:\n{result.stderr[-500:]}"
            )
