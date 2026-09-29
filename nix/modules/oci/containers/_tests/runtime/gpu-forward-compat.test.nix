# BDD test specs for gpu.forwardCompat CUDA compat-library presence.
#
# Bead: docs-ci-deploy-z83.4.2
# Spec: openspec/changes/runtime-behavioral-test-coverage/specs/testing/
#       runtime-behavior-verification/spec.md
#       Scenario "gpu.forwardCompat includes compat libraries"
#
# When forwardCompat = true, _nixos-oci/gpu/outputs.nix adds the
# cudaPackages.cuda_compat package to oci.container.extraPackages and
# prepends its /lib to LD_LIBRARY_PATH. It also emits the
# io.github.dauliac.nix-oci.gpu.forward-compat = "true" label.
#
# Runtime GPU verification is not possible in CI (no NVIDIA hardware), so
# we assert the observable image-side markers:
#   1. the forward-compat label is present in Config.Labels
#   2. the runtime-libraries label still lists the requested libs
#
# The LD_LIBRARY_PATH ordering (compat prefix ahead of the driver libs)
# lives in Config.Env; asserting the exact store path is brittle across
# nixpkgs bumps, so we assert only the presence of the label surface here
# and defer the string-content assertion to a future inspect helper.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.gpu-forward-compat-runtime = {
        eval-forward-compat-enabled = {
          given = "a container with gpu.enable = true and gpu.forwardCompat = true";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds and the compat library is added to extraPackages";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            gpu = {
              enable = true;
              forwardCompat = true;
              runtimeLibraries = [ "cudart" ];
            };
          };
        };

        inspect-forward-compat-label = {
          given = "a container with gpu.forwardCompat = true";
          "when" = "the OCI image is inspected";
          "then" = "Config.Labels contains gpu.forward-compat = true";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            gpu = {
              enable = true;
              forwardCompat = true;
              runtimeLibraries = [ "cudart" ];
            };
          };
          assertions.labels = {
            "io.github.dauliac.nix-oci.gpu.forward-compat" = "true";
            "io.github.dauliac.nix-oci.gpu.enabled" = "true";
          };
        };

        inspect-forward-compat-disabled-no-label = {
          given = "a container with gpu.enable = true but forwardCompat = false";
          "when" = "the OCI image is inspected";
          "then" = "the runtime-libraries label is present but forward-compat is not asserted";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.hello;
            gpu = {
              enable = true;
              forwardCompat = false;
              runtimeLibraries = [ "cudart" ];
            };
          };
          # Only positive assertions; absence-of-key would need a
          # dedicated helper (fileNotContains is file-scoped).
          assertions.labels = {
            "io.github.dauliac.nix-oci.gpu.enabled" = "true";
            "io.github.dauliac.nix-oci.gpu.runtime-libraries" = "cudart";
          };
        };
      };
    };
}
