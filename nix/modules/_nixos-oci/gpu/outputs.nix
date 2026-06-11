{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container.gpu;

  # -- CUDA package mapping --
  #
  # Maps user-friendly library names to actual nixpkgs cudaPackages.
  # cudaPackages layout varies across nixpkgs versions:
  #   - Modern (24.05+): individual packages (cuda_cudart, libcublas, ...)
  #   - Older: monolithic cudatoolkit
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

  # Filter out unavailable packages (null).
  selectedLibs = builtins.filter (p: p != null) (
    map (name: libMap.${name} or null) cfg.runtimeLibraries
  );

  # CUDA forward-compat package (bridges newer CUDA toolkit with older driver).
  cudaCompatPkg = cudaPkgs.cuda_compat or null;

  # Auto-detect CUDA version from cudaPackages when not explicitly set.
  detectedCudaVersion =
    if cfg.cudaVersion != null then
      cfg.cudaVersion
    else
      cudaPkgs.cudaMajorMinorVersion or cudaPkgs.cudaVersion or null;

  capabilitiesStr =
    if builtins.elem "all" cfg.capabilities then "all" else lib.concatStringsSep "," cfg.capabilities;

  # Build LD_LIBRARY_PATH from selected CUDA libs + optional compat prefix.
  cudaLibPath = lib.makeLibraryPath selectedLibs;
  compatPrefix = if cfg.forwardCompat && cudaCompatPkg != null then "${cudaCompatPkg}/lib" else null;
  ldLibraryPath = if compatPrefix != null then "${compatPrefix}:${cudaLibPath}" else cudaLibPath;

  ns = "io.github.dauliac.nix-oci";
in
{
  # -- Warnings --

  config.warnings = lib.optionals cfg.enable [
    ''
      nix-oci: GPU support (gpu.enable) is experimental and not yet
      thoroughly tested across all CUDA versions and GPU architectures.
      Feedback and bug reports are welcome at:
        https://github.com/Dauliac/nix-oci/issues
    ''
  ];

  # -- Assertions --

  config.assertions = lib.optionals cfg.enable [
    {
      assertion = cfg.runtimeLibraries != [ ];
      message = ''
        nix-oci: `gpu.enable = true` but `gpu.runtimeLibraries` is empty.
        At minimum, include `"cudart"` (CUDA runtime) unless your application
        is statically linked against CUDA.
      '';
    }
    {
      assertion = !(cfg.forwardCompat && cudaCompatPkg == null);
      message = ''
        nix-oci: `gpu.forwardCompat = true` but `cudaPackages.cuda_compat`
        is not available in the current nixpkgs. Either update nixpkgs or
        disable forward compatibility.
      '';
    }
    {
      assertion = selectedLibs != [ ] || cfg.runtimeLibraries == [ ];
      message = ''
        nix-oci: some GPU runtime libraries are not available in cudaPackages.
        Requested: ${lib.concatStringsSep ", " cfg.runtimeLibraries}
        Available: ${lib.concatStringsSep ", " (lib.attrNames (lib.filterAttrs (_: v: v != null) libMap))}
        Check that cudaPackages has the requested libraries or remove unavailable ones.
      '';
    }
  ];

  # -- Build artifact outputs --

  options.oci.container._output.gpu = {
    envVars = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      internal = true;
      readOnly = true;
      description = "GPU environment variables as KEY=VALUE strings.";
      default = lib.optionals cfg.enable (
        [
          "NVIDIA_VISIBLE_DEVICES=all"
          "NVIDIA_DRIVER_CAPABILITIES=${capabilitiesStr}"
        ]
        ++ lib.optional (detectedCudaVersion != null) "NVIDIA_REQUIRE_CUDA=cuda>=${detectedCudaVersion}"
        ++ lib.optional (cudaLibPath != "") "LD_LIBRARY_PATH=${ldLibraryPath}"
      );
    };

    extraDeps = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      internal = true;
      readOnly = true;
      description = "CUDA runtime library packages to include in the image.";
      default = lib.optionals cfg.enable (
        selectedLibs ++ lib.optional (cfg.forwardCompat && cudaCompatPkg != null) cudaCompatPkg
      );
    };

    labels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      internal = true;
      readOnly = true;
      description = "OCI labels encoding GPU configuration.";
      default = lib.optionalAttrs cfg.enable (
        {
          "${ns}.gpu.enabled" = "true";
          "${ns}.gpu.capabilities" = capabilitiesStr;
          "${ns}.gpu.runtime-libraries" = lib.concatStringsSep "," cfg.runtimeLibraries;
          "${ns}.gpu.operator-compatible" = "true";
        }
        // lib.optionalAttrs (detectedCudaVersion != null) {
          "${ns}.gpu.cuda-version" = detectedCudaVersion;
        }
        // lib.optionalAttrs cfg.forwardCompat {
          "${ns}.gpu.forward-compat" = "true";
        }
      );
    };
  };
}
