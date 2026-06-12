# BDD test specs for hardening.seccomp option.
#
# This is a flake-parts module (NOT a submodule module).
# Discovered by test-collector.nix via discoverModules(filter=test).
# Contributes to config.perSystem.test.oci.perContainer.
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.hardening-seccomp = {
        eval-defaults = {
          given = "a container with hardening enabled and seccomp defaults";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds without error";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
          };
        };

        inspect-label-present = {
          given = "a container with seccomp moderate profile";
          "when" = "the OCI image is inspected";
          "then" = "the seccomp profile label is present";
          level = "inspect";
          target = "oci";
          container = {
            package = pkgs.busybox;
            isRoot = true;
            hardening.enable = true;
            hardening.seccomp = {
              enable = true;
              profile = "moderate";
            };
          };
          assertions = {
            imageConfig.Labels = {
              "io.github.dauliac.nix-oci.hardening.seccomp-profile" = "moderate";
            };
          };
          exampleFile = ../../../../../../examples/flake/hardening/hardening-full-01.nix;
        };
      };
    };
}
