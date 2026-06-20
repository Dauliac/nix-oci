# GPU outputs: CUDA library injection, NVIDIA env vars, labels.
#
# Uses NixOS-native routing:
#   - environment.variables for NVIDIA env vars
#   - oci.container.extraPackages for CUDA runtime libraries
#   - oci.container.generatedLabels for OCI metadata
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.oci.container.gpu;

  # -- CUDA package mapping --
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

  selectedLibs = builtins.filter (p: p != null) (
    map (name: libMap.${name} or null) cfg.runtimeLibraries
  );

  cudaCompatPkg = cudaPkgs.cuda_compat or null;

  detectedCudaVersion =
    if cfg.cudaVersion != null then
      cfg.cudaVersion
    else
      cudaPkgs.cudaMajorMinorVersion or cudaPkgs.cudaVersion or null;

  capabilitiesStr =
    if builtins.elem "all" cfg.capabilities then "all" else lib.concatStringsSep "," cfg.capabilities;

  cudaLibPath = lib.makeLibraryPath selectedLibs;
  compatPrefix = if cfg.forwardCompat && cudaCompatPkg != null then "${cudaCompatPkg}/lib" else null;
  ldLibraryPath = if compatPrefix != null then "${compatPrefix}:${cudaLibPath}" else cudaLibPath;

  ns = "io.github.dauliac.nix-oci";
in
{
  # Backward-compat: old consumers read _output.gpu.{envVars,extraDeps,labels}.
  # Remove after Phase 5/6 migration.
  options.oci.container._output.gpu = {
    envVars = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      internal = true;
      readOnly = true;
      description = "DEPRECATED: use environment.variables. Kept for backward compat.";
      default = [ ];
    };
    extraDeps = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      internal = true;
      readOnly = true;
      description = "DEPRECATED: use oci.container.extraPackages. Kept for backward compat.";
      default = [ ];
    };
    labels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      internal = true;
      readOnly = true;
      description = "DEPRECATED: use oci.container.generatedLabels. Kept for backward compat.";
      default = { };
    };
  };

  config = lib.mkMerge [
    # -- Warnings & Assertions (always evaluated) --
    {
      warnings = lib.optionals cfg.enable [
        ''
          nix-oci: GPU support (gpu.enable) is experimental and not yet
          thoroughly tested across all CUDA versions and GPU architectures.
          Feedback and bug reports are welcome at:
            https://github.com/Dauliac/nix-oci/issues
        ''
      ];
      assertions = lib.optionals cfg.enable [
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
    }
    # -- Feature config (only when gpu.enable) --
    (lib.mkIf cfg.enable {
      # -- Environment variables (NixOS-native routing) --
      environment.variables = {
        NVIDIA_VISIBLE_DEVICES = "all";
        NVIDIA_DRIVER_CAPABILITIES = capabilitiesStr;
      }
      // lib.optionalAttrs (detectedCudaVersion != null) {
        NVIDIA_REQUIRE_CUDA = "cuda>=${detectedCudaVersion}";
      }
      // lib.optionalAttrs (cudaLibPath != "") {
        LD_LIBRARY_PATH = ldLibraryPath;
      };

      # -- Extra packages (unified routing) --
      oci.container.extraPackages =
        selectedLibs ++ lib.optional (cfg.forwardCompat && cudaCompatPkg != null) cudaCompatPkg;

      # -- Generated labels (unified routing) --
      oci.container.generatedLabels = {
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
      };
    })
  ];
}
