# Example: NixOS deploy -- NVIDIA GPU / CUDA container.
#
# Demonstrates the GPU module options for building containers compatible
# with the NVIDIA GPU Operator in Kubernetes. The container bundles CUDA
# runtime libraries from nixpkgs; driver libraries (libcuda.so, nvidia-smi)
# are injected at runtime by the NVIDIA Container Toolkit on the host.
#
# Prerequisites:
#   - nixpkgs.config.cudaSupport = true
#   - nixpkgs.config.allowUnfree = true  (CUDA packages are unfree)
#
# Deploy to Kubernetes with:
#   resources:
#     limits:
#       nvidia.com/gpu: 1
{ pkgs, ... }:
let
  cuda-hello = pkgs.writeShellApplication {
    name = "cuda-hello";
    runtimeInputs = [ ];
    text = ''
      echo "NVIDIA_VISIBLE_DEVICES=$NVIDIA_VISIBLE_DEVICES"
      echo "NVIDIA_DRIVER_CAPABILITIES=$NVIDIA_DRIVER_CAPABILITIES"
      echo "CUDA runtime library check:"
      ls -la /nix/store/*/lib/libcudart.so* 2>/dev/null || echo "  (not found -- expected in minimal test)"
      echo "GPU container ready. nvidia-smi will be available when deployed with GPU Operator."
    '';
  };
in
{
  oci = {
    enable = true;
    backend = "podman";
    containers.cuda-app = {
      package = cuda-hello;
      dependencies = [ pkgs.coreutils ];
      # nixosConfig triggers the NixOS eval pipeline where GPU
      # env vars and CUDA libraries are baked into the image.
      nixosConfig.modules = [ ];
      autoStart = false;
      ports = [ ];

      # -- GPU support (baked into OCI image) --
      gpu = {
        enable = true;
        # Which driver libraries the NVIDIA Container Toolkit injects at runtime.
        capabilities = [
          "compute"
          "utility"
        ];
        # CUDA toolkit libraries bundled in the image from nixpkgs.cudaPackages.
        runtimeLibraries = [
          "cudart"
          "cublas"
        ];
        # Auto-detected from cudaPackages when null.
        # cudaVersion = "12.2";
      };

      # GPU containers can still use hardening (seccomp auto-selects gpu-compute).
      # hardening.enable = true;
    };
  };
}
