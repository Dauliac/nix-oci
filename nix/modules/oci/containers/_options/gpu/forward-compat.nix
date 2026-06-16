# Shared: CUDA forward compatibility.
#
# When the host driver is older than the CUDA toolkit version
# bundled in the image, forward-compat libraries bridge the gap.
# They translate newer CUDA API calls to the older driver interface.
#
# References:
#   - https://docs.nvidia.com/deploy/cuda-compatibility/
{
  lib,
  ...
}:
{
  options.gpu.forwardCompat = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Include CUDA forward compatibility libraries in the image.

      When enabled, the `cuda-compat` package is added and
      `LD_LIBRARY_PATH` is configured so compat libraries take
      precedence over the host-injected driver libraries.

      This allows the container to use a newer CUDA toolkit than
      the host driver natively supports. Useful when deploying to
      clusters where driver upgrades are infrequent.

      Not all features are forward-compatible -- some require
      kernel-mode driver support for new hardware capabilities.
    '';
  };
}
