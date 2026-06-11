{ lib, ... }:
{
  options.oci.container.gpu = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable NVIDIA GPU support for this container.";
    };
  };
}
