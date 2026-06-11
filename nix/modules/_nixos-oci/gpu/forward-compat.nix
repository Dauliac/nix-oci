{ lib, ... }:
{
  options.oci.container.gpu = {
    forwardCompat = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Include CUDA forward compatibility libraries.";
    };
  };
}
