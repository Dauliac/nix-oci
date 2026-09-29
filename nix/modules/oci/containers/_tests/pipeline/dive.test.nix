# BDD test specs for the dive pipeline step.
#
# Verifies that dive analysis is wired via the gate for enabled
# containers and produces a report artifact. A container whose layers
# waste space (redundant files across layers) is expected to fail dive's
# efficiency threshold at gate time.
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * dive report is generated
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.pipeline-dive = {
        eval-defaults = {
          given = "a container with default test.dive settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-clean-container-passes-dive = {
          given = "a lean single-package container with dive enabled";
          "when" = "dive analyses the image";
          "then" = "the efficiency threshold is satisfied and the gate build succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            test.dive.enabled = true;
          };
        };

        build-wasteful-container-fails-dive = {
          given = "a container that stacks redundant heavy packages across layers";
          "when" = "dive analyses the image";
          "then" = "the efficiency threshold trips and the dive step fails the gate";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            dependencies = [
              pkgs.coreutils
              pkgs.bash
              pkgs.gnugrep
              pkgs.gnused
            ];
            test.dive.enabled = true;
          };
        };
      };
    };
}
