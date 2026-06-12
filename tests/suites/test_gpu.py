"""GPU container tests -- labels, env vars, CUDA libraries.

Only run on NixOS backend (GPU containers require allowUnfree + nixosConfig).
"""

import pytest

NS = "io.github.dauliac.nix-oci"


@pytest.fixture(autouse=True, scope="module")
def _require_nixos(nixos_only):
    """Skip this entire module on non-NixOS backends."""


class TestGpuBasic:
    IMAGE = "gpu-basic:latest"

    def test_gpu_labels(self, image_helper):
        image_helper(self.IMAGE).assert_labels(
            {
                f"{NS}.gpu.enabled": "true",
                f"{NS}.gpu.capabilities": "compute,utility",
                f"{NS}.gpu.operator-compatible": "true",
                f"{NS}.gpu.runtime-libraries": "cudart",
            }
        )

    def test_cuda_version_label_present(self, image_helper):
        h = image_helper(self.IMAGE)
        cuda_ver = h.labels.get(f"{NS}.gpu.cuda-version")
        assert cuda_ver is not None, (
            f"Expected gpu.cuda-version label, got: {list(h.labels.keys())}"
        )
        parts = cuda_ver.split(".")
        assert len(parts) >= 2, f"CUDA version should be X.Y, got: {cuda_ver}"

    def test_nvidia_env_vars(self, image_helper):
        h = image_helper(self.IMAGE)
        env = h.env_dict
        assert env.get("NVIDIA_VISIBLE_DEVICES") == "all", (
            f"NVIDIA_VISIBLE_DEVICES: {env}"
        )
        assert env.get("NVIDIA_DRIVER_CAPABILITIES") == "compute,utility", (
            f"NVIDIA_DRIVER_CAPABILITIES: {env}"
        )
        assert "NVIDIA_REQUIRE_CUDA" in env, f"Missing NVIDIA_REQUIRE_CUDA: {env}"
        assert "LD_LIBRARY_PATH" in env, f"Missing LD_LIBRARY_PATH: {env}"

    def test_libcudart_present(self, run_container):
        output = run_container(
            self.IMAGE,
            "/bin/busybox",
            "find /nix/store -name 'libcudart.so*' -type f",
        )
        assert "libcudart" in output, (
            f"Expected libcudart.so in image, got: {output}"
        )

    def test_busybox_runs(self, run_container):
        run_container(self.IMAGE, "/bin/busybox", "--help")
