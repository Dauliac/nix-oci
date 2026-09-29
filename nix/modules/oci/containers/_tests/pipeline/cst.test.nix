# BDD test specs for the container-structure-test pipeline step.
#
# CST checks the built image against user-supplied YAML configs and,
# when `coherence = true`, an auto-generated metadataTest built from the
# declared module config. A coherent image passes; an image mutated to
# drop a declared surface (e.g. an exposed port) fails.
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * container-structure-test pass/fail on coherent vs mutated image
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      # The hello-cst.yaml fixture in tests/fixtures asserts that basic
      # files exist inside the image. A container matching that
      # description passes; a container that omits a declared surface
      # would fail on the auto-generated coherence config.
      cstFixture = ../../../../../../tests/fixtures/hello-cst.yaml;
    in
    {
      test.oci.perContainer.pipeline-cst = {
        eval-defaults = {
          given = "a container with default test.containerStructureTest settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-cst-user-config-passes = {
          given = "a container passing a hand-written CST config that matches the image";
          "when" = "container-structure-test runs against the image";
          "then" = "all declared assertions pass and the step succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            test.containerStructureTest = {
              enabled = true;
              configs = [ cstFixture ];
            };
          };
        };

        build-cst-coherence-matches-declared = {
          given = "a container with coherence auto-generation and a declared entrypoint + ports";
          "when" = "the CST step runs against the image";
          "then" = "the auto-generated metadataTest JSON matches the observed image config";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            ports = [ "8080:8080" ];
            test.containerStructureTest = {
              enabled = true;
              coherence = true;
            };
          };
        };

        build-cst-coherence-fails-on-mutation = {
          given = "a container declaring an exposed port but shipped with the port stripped from image config";
          "when" = "CST checks the coherence metadataTest against the mutated image";
          "then" = "the exposedPorts assertion fails and the step trips the gate";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            ports = [ "9090:9090" ];
            test.containerStructureTest = {
              enabled = true;
              coherence = true;
            };
          };
        };
      };
    };
}
