# Shared: minimum CUDA version constraint.
#
# Sets NVIDIA_REQUIRE_CUDA to prevent running on hosts with
# incompatible drivers. The NVIDIA Container Toolkit validates
# this before starting the container.
{
  lib,
  pkgs,
  ...
}:
let
  example = "12.2";
in
{
  options.gpu.cudaVersion = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    inherit example;
    description = ''
      Minimum CUDA version constraint.

      When set, the `NVIDIA_REQUIRE_CUDA` environment variable is
      added to the image config (e.g. `cuda>=12.2`). The NVIDIA
      Container Toolkit validates this against the host driver before
      allowing the container to start.

      When `null` (default), the version is auto-detected from the
      `cudaPackages` in nixpkgs.
    '';
  };

  config._tests.gpu-cuda-version = {
    level = "eval";
    default = {
      package = pkgs.hello;
      gpu.enable = true;
    };
    override = {
      package = pkgs.hello;
      gpu.enable = true;
      gpu.cudaVersion = example;
    };
  };
}
