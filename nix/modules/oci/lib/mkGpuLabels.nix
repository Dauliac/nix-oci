# nix-lib: generate OCI labels for GPU configuration.
#
# Produces labels under the io.github.dauliac.nix-oci.gpu.* namespace.
# Called by mkAutoLabels or image builders when GPU support is enabled.
{ lib, ... }:
let
  pure = import ../../../lib/oci.nix { inherit lib; };
in
{
  config.perSystem =
    { lib, ... }:
    {
      nix-lib.lib.oci.mkGpuLabels = {
        type = lib.types.functionTo lib.types.attrs;
        description = "Generate OCI labels encoding GPU configuration and NVIDIA operator compatibility.";
        file = "nix/modules/oci/lib/mkGpuLabels.nix";
        fn = pure.mkGpuLabels;
        tests = {
          "generates labels with CUDA compute" = {
            args = {
              gpu = {
                enable = true;
                capabilities = "compute,utility";
                cudaVersion = "12.2";
                runtimeLibraries = [
                  "cudart"
                  "cublas"
                ];
                forwardCompat = false;
              };
            };
            assertions = [
              {
                name = "has enabled label";
                check = result: result."io.github.dauliac.nix-oci.gpu.enabled" == "true";
              }
              {
                name = "has cuda version label";
                check = result: result."io.github.dauliac.nix-oci.gpu.cuda-version" == "12.2";
              }
              {
                name = "has operator-compatible label";
                check = result: result."io.github.dauliac.nix-oci.gpu.operator-compatible" == "true";
              }
              {
                name = "has runtime libraries label";
                check = result: result."io.github.dauliac.nix-oci.gpu.runtime-libraries" == "cudart,cublas";
              }
            ];
          };
          "returns empty when disabled" = {
            args = {
              gpu = {
                enable = false;
                capabilities = "compute,utility";
                cudaVersion = null;
                runtimeLibraries = [ ];
                forwardCompat = false;
              };
            };
            expected = { };
          };
          "includes forward-compat label" = {
            args = {
              gpu = {
                enable = true;
                capabilities = "all";
                cudaVersion = "12.4";
                runtimeLibraries = [ "cudart" ];
                forwardCompat = true;
              };
            };
            assertions = [
              {
                name = "has forward-compat label";
                check = result: result."io.github.dauliac.nix-oci.gpu.forward-compat" == "true";
              }
            ];
          };
        };
      };
    };
}
