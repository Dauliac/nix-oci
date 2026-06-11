# Shared: NVIDIA GPU support master switch.
{
  lib,
  pkgs,
  ...
}:
{
  options.gpu.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Enable NVIDIA GPU support for this container.

      When enabled, sets environment variables that trigger the NVIDIA
      Container Toolkit runtime injection (`NVIDIA_VISIBLE_DEVICES`,
      `NVIDIA_DRIVER_CAPABILITIES`) and includes CUDA runtime libraries
      from nixpkgs in the container image.

      Compatible with the NVIDIA GPU Operator in Kubernetes -- images
      built with this option work with both legacy (env-var) and CDI
      (Container Device Interface) injection modes.

      Driver libraries (`libcuda.so`, `libnvidia-ml.so`, `nvidia-smi`)
      are NOT bundled -- they are always injected at runtime by the
      host's NVIDIA Container Toolkit.

      Requires `nixpkgs.config.cudaSupport = true` and
      `nixpkgs.config.allowUnfree = true` in the consuming flake.
    '';
  };

  config._tests.gpu-enable = {
    level = "eval";
    default = {
      package = pkgs.hello;
    };
    override = {
      package = pkgs.hello;
      gpu.enable = true;
    };
  };
}
