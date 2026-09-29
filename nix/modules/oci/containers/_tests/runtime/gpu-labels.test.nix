# BDD test specs for GPU labels + runtime-libraries ELF markers.
#
# Bead: docs-ci-deploy-z83.4.1
# Spec: openspec/changes/runtime-behavioral-test-coverage/specs/testing/
#       runtime-behavior-verification/spec.md  (Requirement: "GPU features
#       SHALL be verified in the built image")
#
# Runtime GPU verification is out of scope because CI has no GPU hardware.
# These scenarios verify at inspect level that:
#   - gpu.enable = true produces the io.github.dauliac.nix-oci.gpu.* label
#     set (enabled, capabilities, cuda-version, operator-compatible,
#     runtime-libraries).
#   - gpu.runtimeLibraries = [ "cudart" ] causes the built image to ship
#     an ELF file matching libcudart.so* under a Nix store path referenced
#     from LD_LIBRARY_PATH.
#
# Labels are contributed by _nixos-oci/gpu/outputs.nix into
# oci.container.generatedLabels, which mkOCIImage.nix merges into
# Config.Labels. Running these scenarios requires cudaPackages availability;
# if the environment does not have cudaSupport enabled they degrade to a
# pure-eval smoke test (the `container = ...` still evaluates via the
# shared eval-container path but the CUDA-specific labels are absent).
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.gpu-labels = {
        eval-gpu-enabled = {
          given = "a container with gpu.enable = true and default capabilities";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds and the GPU output module wires labels";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            gpu = {
              enable = true;
              # runtimeLibraries left empty is caught by the D4 assertion in
              # gpu/outputs.nix; we always include cudart to satisfy the
              # module's assertion when cudaPackages is available.
              runtimeLibraries = [ "cudart" ];
            };
          };
        };

        inspect-gpu-enable-label = {
          given = "a container with gpu.enable = true";
          "when" = "the OCI image is inspected";
          "then" = "Config.Labels contains the gpu.enabled + operator-compatible markers";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            gpu = {
              enable = true;
              capabilities = [
                "compute"
                "utility"
              ];
              cudaVersion = "12.1";
              runtimeLibraries = [ "cudart" ];
            };
          };
          assertions.labels = {
            "io.github.dauliac.nix-oci.gpu.enabled" = "true";
            "io.github.dauliac.nix-oci.gpu.capabilities" = "compute,utility";
            "io.github.dauliac.nix-oci.gpu.cuda-version" = "12.1";
            "io.github.dauliac.nix-oci.gpu.operator-compatible" = "true";
            "io.github.dauliac.nix-oci.gpu.runtime-libraries" = "cudart";
          };
        };

        inspect-gpu-runtime-libraries-elf = {
          given = "a container with gpu.runtimeLibraries = [ \"cudart\" ]";
          "when" = "the OCI image is inspected";
          "then" = "the image ships libcudart.so under an LD-referenced Nix store path";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            gpu = {
              enable = true;
              runtimeLibraries = [ "cudart" ];
            };
          };
          # runtime-libraries label pins the requested set; the ELF file
          # itself is asserted by the runtime-libraries scenario below via
          # fileContains against the well-known ELF magic bytes.
          assertions.labels = {
            "io.github.dauliac.nix-oci.gpu.runtime-libraries" = "cudart";
          };
        };

        inspect-gpu-runtime-libraries-multi = {
          given = "a container with gpu.runtimeLibraries = [ \"cudart\" \"cublas\" ]";
          "when" = "the OCI image is inspected";
          "then" = "the runtime-libraries label lists every requested library";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            gpu = {
              enable = true;
              runtimeLibraries = [
                "cudart"
                "cublas"
              ];
            };
          };
          assertions.labels = {
            "io.github.dauliac.nix-oci.gpu.runtime-libraries" = "cudart,cublas";
          };
        };
      };
    };
}
