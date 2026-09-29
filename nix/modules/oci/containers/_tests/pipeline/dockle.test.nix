# BDD test specs for the dockle pipeline step.
#
# Verifies that dockle's exitLevel gates the build: FATAL findings block
# the gate at that level and above, and the ignore list suppresses named
# checkpoint IDs so the gate passes despite matching findings.
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * dockle exit-level gates the build
#   * dockle ignore list suppresses issues
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.pipeline-dockle = {
        eval-defaults = {
          given = "a container with default lint.dockle settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-nonroot-passes-fatal = {
          given = "a non-root container with dockle exitLevel = fatal";
          "when" = "dockle lints the image";
          "then" = "no FATAL findings trip and the gate build succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            lint.dockle = {
              enabled = true;
              exitLevel = "fatal";
            };
          };
        };

        build-warn-level-gates-warns = {
          given = "a container with dockle exitLevel lowered to warn";
          "when" = "dockle emits a WARN-level finding (e.g. missing HEALTHCHECK)";
          "then" = "the lowered exit level trips the gate on any WARN, unlike the default fatal";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            lint.dockle = {
              enabled = true;
              exitLevel = "warn";
            };
          };
        };

        build-ignore-suppresses-checkpoint = {
          given = "a container that would trip CIS-DI-0001 (run as root)";
          "when" = "the checkpoint is listed in lint.dockle.ignore";
          "then" = "the finding is suppressed and the gate build succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
            lint.dockle = {
              enabled = true;
              exitLevel = "fatal";
              ignore = [
                "CIS-DI-0001"
                "CIS-DI-0005"
                "CIS-DI-0006"
                "DKL-DI-0006"
              ];
            };
          };
        };
      };
    };
}
