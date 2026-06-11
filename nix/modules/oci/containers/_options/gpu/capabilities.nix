# Shared: NVIDIA driver capabilities requested at runtime.
#
# Controls which driver libraries the NVIDIA Container Toolkit injects
# into the container at start time. Maps directly to the
# NVIDIA_DRIVER_CAPABILITIES environment variable.
#
# References:
#   - https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/docker-specialized.html
#   - https://github.com/NVIDIA/libnvidia-container (nvc_info.c)
{ lib, ... }:
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

      - `"compute"` -- CUDA and OpenCL libraries (`libcuda.so`,
        `libnvidia-ptxjitcompiler.so`, `libnvidia-nvvm.so`).
        Required for any CUDA workload.

      - `"utility"` -- Management tools and libraries (`nvidia-smi`,
        `libnvidia-ml.so`). Useful for GPU monitoring.

      - `"graphics"` -- OpenGL, EGL, Vulkan, and OptiX libraries
        (`libGLX_nvidia.so`, `libEGL_nvidia.so`, `libnvoptix.so`).
        Required for rendering workloads.

      - `"video"` -- Hardware video codec libraries (`libnvidia-encode.so`,
        `libnvcuvid.so`). Required for NVENC/NVDEC transcoding.

      - `"display"` -- X11 display output libraries. Rarely needed
        in server containers.

      - `"all"` -- All capabilities above.

      Default: `["compute" "utility"]` (CUDA compute + nvidia-smi).
    '';
  };
}
