# BDD test specs for the trivy secret / credentials-leak pipeline step.
#
# Verifies that trivy secret scanning flags a container that ships a
# file with an AWS access-key-id shape, and passes a clean container.
# The leaky fixture is a writeTextDir package added to `dependencies`
# so it becomes part of the container closure.
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * trivy secret scan flags leaked credentials
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      # An AWS access key id has the shape AKIA + 16 uppercase alnums.
      # Placing this shape in a file inside the container closure is
      # what trivy's built-in secret rules key on.
      leakyKeyFixture = pkgs.writeTextDir "etc/leaky-config.env" ''
        # Test fixture: intentionally contains an AWS access key id shape
        # to exercise trivy secret detection. Not a real credential.
        AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
        AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
      '';

      cleanReadmeFixture = pkgs.writeTextDir "etc/readme.txt" ''
        Plain fixture with no credential-shaped content.
      '';
    in
    {
      test.oci.perContainer.pipeline-trivy-secret = {
        eval-defaults = {
          given = "a container with default credentialsLeak.trivy settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-clean-container-passes = {
          given = "a container that ships only a plain README fixture";
          "when" = "trivy scans the image for secrets";
          "then" = "no secret findings surface and the gate build succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            dependencies = [ cleanReadmeFixture ];
            credentialsLeak.trivy.enabled = true;
          };
        };

        build-leaky-container-fails = {
          given = "a container shipping a file matching an AWS access-key-id pattern";
          "when" = "trivy scans the image for secrets";
          "then" = "the secret rule fires and the credentials-leak step fails the gate";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            dependencies = [ leakyKeyFixture ];
            credentialsLeak.trivy.enabled = true;
          };
        };
      };
    };
}
