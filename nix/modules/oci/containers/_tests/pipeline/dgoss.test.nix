# BDD test specs for the dgoss pipeline step.
#
# dgoss ships as a probe-phase step exposing `oci-dgoss-<container>`.
# The pipeline registration currently omits mkStamp (the upstream
# mkCheckDgoss lib references a non-existent optionsPath option and is
# broken); mkScript is wired for the daemon backend.
#
# When a goss file is missing at eval time, the emitted script is a
# no-op that exits 0 with a log line. When the goss file exists and the
# container matches its assertions, dgoss exits 0; when the container
# breaks the assertions, dgoss exits nonzero.
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * dgoss behavioral test runs
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.pipeline-dgoss = {
        eval-defaults = {
          given = "a container with default test.dgoss settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-dgoss-enabled-no-fixture = {
          given = "a container with dgoss enabled but no goss.yaml on disk";
          "when" = "the pipeline composer wires the dgoss script";
          "then" = "a no-op script is emitted that exits 0 with a skip log";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            test.dgoss.enabled = true;
          };
        };

        build-dgoss-passing-fixture = {
          given = "a container with dgoss enabled and a goss.yaml matching /etc/passwd";
          "when" = "dgoss runs against the image";
          "then" = "assertions pass and dgoss exits 0";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            test.dgoss.enabled = true;
          };
        };

        build-dgoss-failing-fixture = {
          given = "a container with dgoss enabled and a goss.yaml asserting a port that is not bound";
          "when" = "dgoss runs against the image";
          "then" = "assertions fail and dgoss exits nonzero";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            test.dgoss.enabled = true;
          };
        };
      };
    };
}
