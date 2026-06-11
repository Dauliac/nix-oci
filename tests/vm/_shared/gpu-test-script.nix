# Shared Python test body for GPU container tests.
# Used by the consolidated NixOS VM test.
''
def run_gpu_tests(m):
    """Run GPU container tests (labels, env vars, CUDA libs)."""

    NS = "io.github.dauliac.nix-oci"

    with subtest("load gpu-basic image"):
        m.wait_for_unit("oci-load-gpu-basic.service")

    with subtest("gpu-basic: GPU labels"):
        img = "gpu-basic:latest"
        info = image_inspect(m, img)
        labels = info.get("Labels", {})
        for key, val in [
            (f"{NS}.gpu.enabled", "true"),
            (f"{NS}.gpu.capabilities", "compute,utility"),
            (f"{NS}.gpu.operator-compatible", "true"),
            (f"{NS}.gpu.runtime-libraries", "cudart"),
        ]:
            actual = labels.get(key, None)
            assert actual == val, f"Expected label {key}={val}, got: {actual}"

    with subtest("gpu-basic: CUDA version label present"):
        info = image_inspect(m, "gpu-basic:latest")
        labels = info.get("Labels", {})
        cuda_ver = labels.get(f"{NS}.gpu.cuda-version", None)
        assert cuda_ver is not None, \
            f"Expected gpu.cuda-version label, got: {list(labels.keys())}"
        parts = cuda_ver.split(".")
        assert len(parts) >= 2, f"CUDA version should be X.Y, got: {cuda_ver}"

    with subtest("gpu-basic: NVIDIA env vars"):
        info = image_inspect(m, "gpu-basic:latest")
        env_list = info.get("Config", {}).get("Env", [])
        env_dict = {}
        for entry in env_list:
            k, _, v = entry.partition("=")
            env_dict[k] = v

        assert env_dict.get("NVIDIA_VISIBLE_DEVICES") == "all", \
            f"NVIDIA_VISIBLE_DEVICES: {env_dict}"
        assert env_dict.get("NVIDIA_DRIVER_CAPABILITIES") == "compute,utility", \
            f"NVIDIA_DRIVER_CAPABILITIES: {env_dict}"
        assert "NVIDIA_REQUIRE_CUDA" in env_dict, \
            f"Missing NVIDIA_REQUIRE_CUDA: {env_dict}"
        assert "LD_LIBRARY_PATH" in env_dict, \
            f"Missing LD_LIBRARY_PATH: {env_dict}"

    with subtest("gpu-basic: libcudart present in image"):
        result = m.succeed(
            "podman run --rm --entrypoint /bin/busybox gpu-basic:latest "
            "find /nix/store -name 'libcudart.so*' -type f 2>/dev/null | head -1"
        )
        assert "libcudart" in result, \
            f"Expected libcudart.so in image, find returned: {result}"

    with subtest("gpu-basic: busybox runs"):
        m.succeed(
            "podman run --rm --entrypoint /bin/busybox gpu-basic:latest --help"
        )
''
