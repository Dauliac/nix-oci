# GPU support test -- validates NVIDIA/CUDA options in a NixOS VM.
#
# Containers are built via the deploy module with GPU options, loaded
# into podman, and tested with `podman image inspect`.
#
# Validates:
#   - GPU labels: gpu.enabled, gpu.capabilities, gpu.operator-compatible,
#                 gpu.runtime-libraries, gpu.cuda-version
#   - NVIDIA env vars: NVIDIA_VISIBLE_DEVICES, NVIDIA_DRIVER_CAPABILITIES,
#                      NVIDIA_REQUIRE_CUDA, LD_LIBRARY_PATH
#   - CUDA runtime libraries are present in the image filesystem
#
# Prerequisites:
#   Requires nixpkgs.config.allowUnfree = true (CUDA packages are unfree).
#
# Run: nix build .#checks.x86_64-linux.vm-gpu -L
{
  config,
  inputs,
  ...
}:
let
  nixosModule = config.flake.modules.nixos.nix-oci;
in
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      # CUDA packages are unfree -- import nixpkgs with allowUnfree for this test.
      # This is only evaluated when `nix build .#checks.x86_64-linux.vm-gpu` is run.
      pkgsUnfree = import inputs.nixpkgs {
        localSystem = system;
        config = {
          allowUnfree = true;
        };
      };
      testHelpers = import ../lib.nix {
        pkgs = pkgsUnfree;
        inherit lib;
      };
    in
    {
      checks = lib.optionalAttrs pkgs.stdenv.isLinux {
        vm-gpu = testHelpers.mkVMTest {
          name = "nix-oci-gpu";

          nodes.machine =
            { pkgs, ... }:
            {
              imports = [ nixosModule ];

              virtualisation.podman.enable = true;

              oci = {
                enable = true;
                backend = "podman";
                containers = {
                  gpu-basic = {
                    package = pkgs.busybox;
                    isRoot = true;
                    nixosConfig.modules = [ ];
                    gpu = {
                      enable = true;
                      capabilities = [
                        "compute"
                        "utility"
                      ];
                      runtimeLibraries = [ "cudart" ];
                    };
                  };
                };
              };
            };

          testScript = ''
            import json

            machine.wait_for_unit("multi-user.target")

            NS = "io.github.dauliac.nix-oci"


            def wait_for_load(name):
                machine.wait_for_unit(f"oci-load-{name}.service")


            def image_inspect(image_ref):
                raw = machine.succeed(f"podman image inspect {image_ref}")
                return json.loads(raw)[0]


            def assert_label(image_ref, key, value):
                """Assert an OCI label matches expected value."""
                info = image_inspect(image_ref)
                labels = info.get("Labels", {})
                actual = labels.get(key, None)
                assert actual == value, \
                    f"Expected label {key}={value} in {image_ref}, got: {actual}"


            def assert_env(image_ref, key, expected_value=None):
                """Assert an env var is set in the image config."""
                info = image_inspect(image_ref)
                env_list = info.get("Config", {}).get("Env", [])
                found = None
                for entry in env_list:
                    if entry.startswith(f"{key}="):
                        found = entry.split("=", 1)[1]
                        break
                assert found is not None, \
                    f"Expected env var {key} in {image_ref}, got: {env_list}"
                if expected_value is not None:
                    assert found == expected_value, \
                        f"Expected {key}={expected_value}, got: {key}={found}"


            # ===================================================================
            # Load GPU image
            # ===================================================================

            with subtest("load gpu-basic image"):
                wait_for_load("gpu-basic")

            # ===================================================================
            # gpu-basic: labels
            # ===================================================================

            with subtest("gpu-basic: GPU labels"):
                img = "gpu-basic:latest"
                assert_label(img, f"{NS}.gpu.enabled", "true")
                assert_label(img, f"{NS}.gpu.capabilities", "compute,utility")
                assert_label(img, f"{NS}.gpu.operator-compatible", "true")
                assert_label(img, f"{NS}.gpu.runtime-libraries", "cudart")

            with subtest("gpu-basic: CUDA version label present"):
                img = "gpu-basic:latest"
                info = image_inspect(img)
                labels = info.get("Labels", {})
                cuda_ver = labels.get(f"{NS}.gpu.cuda-version", None)
                assert cuda_ver is not None, \
                    f"Expected gpu.cuda-version label, got labels: {list(labels.keys())}"
                # Version should be a numeric string like "12.2" or "12.8"
                parts = cuda_ver.split(".")
                assert len(parts) >= 2, f"CUDA version should be X.Y, got: {cuda_ver}"

            # ===================================================================
            # gpu-basic: NVIDIA environment variables
            # ===================================================================

            with subtest("gpu-basic: NVIDIA_VISIBLE_DEVICES env var"):
                assert_env("gpu-basic:latest", "NVIDIA_VISIBLE_DEVICES", "all")

            with subtest("gpu-basic: NVIDIA_DRIVER_CAPABILITIES env var"):
                assert_env("gpu-basic:latest", "NVIDIA_DRIVER_CAPABILITIES", "compute,utility")

            with subtest("gpu-basic: NVIDIA_REQUIRE_CUDA env var"):
                assert_env("gpu-basic:latest", "NVIDIA_REQUIRE_CUDA")

            with subtest("gpu-basic: LD_LIBRARY_PATH env var"):
                assert_env("gpu-basic:latest", "LD_LIBRARY_PATH")

            # ===================================================================
            # gpu-basic: CUDA runtime library in image
            # ===================================================================

            with subtest("gpu-basic: libcudart present in image"):
                result = machine.succeed(
                    "podman run --rm --entrypoint /bin/busybox gpu-basic:latest "
                    "find /nix/store -name 'libcudart.so*' -type f 2>/dev/null | head -1"
                )
                assert "libcudart" in result, \
                    f"Expected libcudart.so in image, find returned: {result}"

            with subtest("gpu-basic: busybox runs"):
                machine.succeed(
                    "podman run --rm --entrypoint /bin/busybox gpu-basic:latest --help"
                )
          '';
        };
      };
    };
}
