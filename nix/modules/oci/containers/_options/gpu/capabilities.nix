# Shared: NVIDIA driver capabilities requested at runtime.
#
# Controls which driver libraries the NVIDIA Container Toolkit injects
# into the container at start time. Maps directly to the
# NVIDIA_DRIVER_CAPABILITIES environment variable.
#
# References:
#   - https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/docker-specialized.html
#   - https://github.com/NVIDIA/libnvidia-container (nvc_info.c)
{
  lib,
  ...
}:
{
  options.gpu.capabilities = lib.mkOption {
    type = lib.types.listOf (
      lib.types.enum [
        "compute"
        "utility"
        "graphics"
        "video"
        "display"
        "all"
      ]
    );
    default = [
      "compute"
      "utility"
    ];
    description = ''
      NVIDIA driver capabilities to request at runtime.

      Each capability controls which host driver libraries the NVIDIA
      Container Toolkit bind-mounts into the container:

      - `"compute"` -- CUDA and OpenCL libraries.
      - `"utility"` -- Management tools (`nvidia-smi`, `libnvidia-ml.so`).
      - `"graphics"` -- OpenGL, EGL, Vulkan, OptiX libraries.
      - `"video"` -- Hardware video codec libraries (NVENC/NVDEC).
      - `"display"` -- X11 display output libraries.
      - `"all"` -- All capabilities above.

      Default: `["compute" "utility"]` (CUDA compute + nvidia-smi).
    '';
  };
}
