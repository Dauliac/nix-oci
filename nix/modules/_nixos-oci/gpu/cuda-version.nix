{ lib, ... }:
{
  options.oci.container.gpu = {
    cudaVersion = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Minimum CUDA version constraint (auto-detected from cudaPackages when null).";
    };
  };
}
