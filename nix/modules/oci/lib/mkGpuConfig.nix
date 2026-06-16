# nix-lib: resolve GPU/CUDA packages, env vars, and labels from config.
#
# Pure function that maps library names to cudaPackages, builds
# LD_LIBRARY_PATH, and generates NVIDIA environment variables.
{ lib, ... }:
{
  config.perSystem =
    {
      pkgs,
      lib,
      ...
    }:
    let
      cudaPkgs = pkgs.cudaPackages or { };

      libMap = {
        cudart = cudaPkgs.cuda_cudart.lib or cudaPkgs.cuda_cudart or null;
        cublas = cudaPkgs.libcublas.lib or cudaPkgs.libcublas or null;
        cufft = cudaPkgs.libcufft.lib or cudaPkgs.libcufft or null;
        curand = cudaPkgs.libcurand.lib or cudaPkgs.libcurand or null;
        cusolver = cudaPkgs.libcusolver.lib or cudaPkgs.libcusolver or null;
        cusparse = cudaPkgs.libcusparse.lib or cudaPkgs.libcusparse or null;
        cudnn = cudaPkgs.cudnn.lib or cudaPkgs.cudnn or null;
        tensorrt = cudaPkgs.tensorrt.lib or cudaPkgs.tensorrt or null;
        nccl = cudaPkgs.nccl or null;
        cutlass = cudaPkgs.cutlass or null;
        nvjpeg = cudaPkgs.libnvjpeg.lib or cudaPkgs.libnvjpeg or null;
      };

      cudaCompatPkg = cudaPkgs.cuda_compat or null;
    in
    {
      nix-lib.lib.oci.mkGpuConfig = {
        type = lib.types.functionTo lib.types.attrs;
        description = ''
          Resolve CUDA libraries, environment variables, and extra dependencies
          from GPU configuration.

          Returns:
            {
              envVars    — list of KEY=VALUE strings
              extraDeps  — list of packages to include in the image
              cudaVersion — detected or explicit CUDA version string
            }
        '';
        file = "nix/modules/oci/lib/mkGpuConfig.nix";
        fn =
          { gpu }:
          let
            cfg = gpu;
            selectedLibs = builtins.filter (p: p != null) (
              map (name: libMap.${name} or null) (cfg.runtimeLibraries or [ ])
            );

            detectedCudaVersion =
              if cfg.cudaVersion or null != null then
                cfg.cudaVersion
              else
                cudaPkgs.cudaMajorMinorVersion or cudaPkgs.cudaVersion or null;

            capabilitiesStr =
              if builtins.elem "all" (cfg.capabilities or [ ]) then
                "all"
              else
                lib.concatStringsSep "," (cfg.capabilities or [ ]);

            cudaLibPath = lib.makeLibraryPath selectedLibs;
            compatPrefix =
              if (cfg.forwardCompat or false) && cudaCompatPkg != null then
                "${cudaCompatPkg}/lib"
              else
                null;
            ldLibraryPath =
              if compatPrefix != null then "${compatPrefix}:${cudaLibPath}" else cudaLibPath;
          in
          {
            envVars = lib.optionals (cfg.enable or false) (
              [
                "NVIDIA_VISIBLE_DEVICES=all"
                "NVIDIA_DRIVER_CAPABILITIES=${capabilitiesStr}"
              ]
              ++ lib.optional (detectedCudaVersion != null) "NVIDIA_REQUIRE_CUDA=cuda>=${detectedCudaVersion}"
              ++ lib.optional (cudaLibPath != "") "LD_LIBRARY_PATH=${ldLibraryPath}"
            );

            extraDeps = lib.optionals (cfg.enable or false) (
              selectedLibs
              ++ lib.optional ((cfg.forwardCompat or false) && cudaCompatPkg != null) cudaCompatPkg
            );

            cudaVersion = detectedCudaVersion;
          };
      };
    };
}
