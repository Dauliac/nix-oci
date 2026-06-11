{ lib, ... }:
{
  options.oci.container.gpu = {
    capabilities = lib.mkOption {
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
      description = "NVIDIA driver capabilities to request at runtime.";
    };
  };
}
