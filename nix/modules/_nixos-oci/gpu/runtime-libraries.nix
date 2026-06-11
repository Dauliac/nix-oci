{ lib, ... }:
{
  options.oci.container.gpu = {
    runtimeLibraries = lib.mkOption {
      type = lib.types.listOf (
        lib.types.enum [
          "cudart"
          "cublas"
          "cufft"
          "curand"
          "cusolver"
          "cusparse"
          "cudnn"
          "tensorrt"
          "nccl"
          "cutlass"
          "nvjpeg"
        ]
      );
      default = [ "cudart" ];
      description = "CUDA toolkit libraries to include in the image.";
    };
  };
}
