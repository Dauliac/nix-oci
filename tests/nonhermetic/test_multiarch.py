"""Multi-architecture build and manifest validation (replaces multi-arch.bats).

Tests OCI push-tmp per-arch builds, merge validation, and multiarch
package manifests.
"""

import json
import os
import shutil
import subprocess
import tempfile

import pytest

from conftest import apps_for_prefix, nix_build, nix_run, pkgs_for_prefix


# -- Fixtures ----------------------------------------------------------------


@pytest.fixture(scope="module")
def oci_dir(tmp_path_factory):
    """Temporary OCI layout directory, shared across tests in module."""
    return tmp_path_factory.mktemp("oci")


# -- Discovery ---------------------------------------------------------------


def _current_arch():
    import platform

    return {"x86_64": "amd64", "aarch64": "arm64"}.get(
        platform.machine(), "unknown"
    )


ARCH = _current_arch()
PUSH_TMP_APPS = apps_for_prefix(f"oci-push-tmp-")
PUSH_TMP_ARCH_APPS = [a for a in PUSH_TMP_APPS if a.endswith(f"-{ARCH}")]
MERGE_APPS = apps_for_prefix("oci-merge-")
MULTIARCH_PKGS = pkgs_for_prefix("oci-multiarch-")


# -- Push temp per-arch images -----------------------------------------------


@pytest.mark.skipif(not PUSH_TMP_ARCH_APPS, reason="no push-tmp apps for current arch")
class TestPushTmp:
    @pytest.mark.parametrize("app", PUSH_TMP_ARCH_APPS, ids=PUSH_TMP_ARCH_APPS)
    def test_push_tmp_succeeds(self, flake_ref, app):
        result = nix_run(flake_ref, app)
        assert result.returncode == 0, (
            f"{app} failed:\n{result.stderr[-500:]}"
        )

    def test_push_tmp_creates_valid_oci_layout(self, flake_ref, oci_dir):
        """First push-tmp app should produce oci-layout + index.json + blobs/."""
        app = PUSH_TMP_ARCH_APPS[0]
        # Clean and set OCI_DIR for the app script
        layout_dir = oci_dir / "layout"
        if layout_dir.exists():
            shutil.rmtree(layout_dir)
        layout_dir.mkdir()

        env = {**os.environ, "OCI_DIR": str(layout_dir)}
        result = subprocess.run(
            ["nix", "run", f"{flake_ref}#{app}"],
            capture_output=True,
            text=True,
            timeout=600,
            env=env,
        )
        assert result.returncode == 0, result.stderr[-500:]
        assert (layout_dir / "oci-layout").exists(), "missing oci-layout"
        assert (layout_dir / "index.json").exists(), "missing index.json"
        assert (layout_dir / "blobs").is_dir(), "missing blobs/"


# -- Merge (expect failure with only one arch) -------------------------------


@pytest.mark.skipif(not MERGE_APPS, reason="no merge apps discovered")
class TestMerge:
    def test_merge_fails_when_missing_architecture(self, flake_ref, oci_dir):
        """Merge must fail when only one architecture was pushed."""
        for merge_app in MERGE_APPS:
            container_id = merge_app.removeprefix("oci-merge-")
            push_app = f"oci-push-tmp-{container_id}-{ARCH}"

            if push_app not in PUSH_TMP_ARCH_APPS:
                continue

            # Clean OCI dir
            layout_dir = oci_dir / "merge"
            if layout_dir.exists():
                shutil.rmtree(layout_dir)
            layout_dir.mkdir()

            env = {**os.environ, "OCI_DIR": str(layout_dir)}

            # Push single arch
            r = subprocess.run(
                ["nix", "run", f"{flake_ref}#{push_app}"],
                capture_output=True,
                text=True,
                timeout=600,
                env=env,
            )
            assert r.returncode == 0, f"push failed: {r.stderr[-300:]}"

            # Merge should fail (missing other arch)
            r = subprocess.run(
                ["nix", "run", f"{flake_ref}#{merge_app}"],
                capture_output=True,
                text=True,
                timeout=600,
                env=env,
            )
            assert r.returncode != 0, (
                f"{merge_app} should fail with single arch, but succeeded"
            )
            return  # one is enough to validate

        pytest.skip("no matching push-tmp/merge pair found")


# -- Multiarch packages: manifest validation ---------------------------------


@pytest.mark.skipif(not MULTIARCH_PKGS, reason="no multiarch packages discovered")
class TestMultiarchPackages:
    @pytest.mark.parametrize("pkg", MULTIARCH_PKGS, ids=MULTIARCH_PKGS)
    def test_manifest_has_multiple_architectures(self, flake_ref, pkg):
        """OCI index must list 2+ architectures, all linux."""
        layout = nix_build(flake_ref, pkg)
        manifest_raw = subprocess.run(
            ["skopeo", "inspect", "--raw", f"oci:{layout}:latest"],
            capture_output=True,
            text=True,
        )
        assert manifest_raw.returncode == 0, manifest_raw.stderr
        manifest = json.loads(manifest_raw.stdout)

        assert manifest["mediaType"] == "application/vnd.oci.image.index.v1+json"

        archs = [m["platform"]["architecture"] for m in manifest["manifests"]]
        assert len(archs) >= 2, f"Expected 2+ architectures, got: {archs}"

        oses = {m["platform"]["os"] for m in manifest["manifests"]}
        assert oses == {"linux"}, f"Expected only linux, got: {oses}"

    @pytest.mark.parametrize("pkg", MULTIARCH_PKGS, ids=MULTIARCH_PKGS)
    def test_per_arch_manifests_have_layers(self, flake_ref, pkg):
        """Each per-arch manifest must have at least one layer."""
        layout = nix_build(flake_ref, pkg)

        index_path = os.path.join(layout, "index.json")
        with open(index_path) as f:
            index = json.load(f)

        for entry in index["manifests"]:
            media = entry.get("mediaType", "")
            if media != "application/vnd.oci.image.manifest.v1+json":
                continue
            tag = entry.get("annotations", {}).get(
                "org.opencontainers.image.ref.name"
            )
            if not tag:
                continue

            arch_raw = subprocess.run(
                ["skopeo", "inspect", "--raw", f"oci:{layout}:{tag}"],
                capture_output=True,
                text=True,
            )
            assert arch_raw.returncode == 0, arch_raw.stderr
            arch_manifest = json.loads(arch_raw.stdout)

            assert arch_manifest["mediaType"] == (
                "application/vnd.oci.image.manifest.v1+json"
            )
            layers = arch_manifest.get("layers", [])
            assert len(layers) >= 1, (
                f"Tag {tag}: expected at least 1 layer, got {len(layers)}"
            )
