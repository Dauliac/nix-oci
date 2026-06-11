# Shared: CUDA runtime libraries to include in the image.
#
# These are user-space libraries bundled at build time from
# nixpkgs.cudaPackages. They provide the CUDA runtime API that
# applications link against.
#
# Driver libraries (libcuda.so, libnvidia-ml.so) are NOT included
# here -- they are always injected at runtime by the host.
{ lib, ... }:
{
  options.gpu.runtimeLibraries = lib.mkOption {
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
    description = ''
      CUDA toolkit libraries to include in the container image.

      - `"cudart"` -- CUDA runtime (`libcudart.so`). Almost always needed.
      - `"cublas"` -- cuBLAS linear algebra.
      - `"cufft"` -- cuFFT Fourier transforms.
      - `"curand"` -- cuRAND random number generation.
      - `"cusolver"` -- cuSOLVER dense/sparse solvers.
      - `"cusparse"` -- cuSPARSE sparse matrix operations.
      - `"cudnn"` -- cuDNN deep learning primitives.
      - `"tensorrt"` -- TensorRT inference optimization.
      - `"nccl"` -- NCCL multi-GPU/node communication.
      - `"cutlass"` -- CUTLASS GEMM templates.
      - `"nvjpeg"` -- nvJPEG hardware JPEG decoding.

      Only selected libraries are included to minimize image size.
      Driver libraries (`libcuda.so`) are never bundled.
    '';
    example = [
      "cudart"
      "cublas"
      "cudnn"
    ];
  };
}
