# Shared: minimum CUDA version constraint.
#
# Sets NVIDIA_REQUIRE_CUDA to prevent running on hosts with
# incompatible drivers. The NVIDIA Container Toolkit validates
# this before starting the container.
{ lib, ... }:
{
  options.gpu.cudaVersion = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "12.2";
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
}
