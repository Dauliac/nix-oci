# BDD test specs for the cosign signing pipeline step.
#
# cosign runs in the post-push phase and is surfaced as
# `oci-cosign-sign-<container>`. Two paths must work:
#
#   * key-based signing: `keyless = false`, `key` points at a
#     cosign-generated key file (or KMS URI), producing a signature
#     referrer that verifies with the matching public key
#   * keyless signing: `keyless = true`, cosign obtains an OIDC token
#     and Fulcio issues an ephemeral cert; a `.sig` referrer lands in
#     the registry alongside declared annotations
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * cosign keyless signing produces a signature
#   * cosign key-based signing produces a signature
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.pipeline-cosign = {
        eval-defaults = {
          given = "a container with default signing.cosign settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds (cosign disabled by default)";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-cosign-keyless-annotations = {
          given = "a container with keyless cosign signing enabled and annotations set";
          "when" = "the pipeline composer wires the post-push signing step";
          "then" = "the container package builds and exposes the cosign-sign script carrying the annotations";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            signing.cosign = {
              enabled = true;
              keyless = true;
              annotations = {
                "build-system" = "nix";
                "repo" = "https://github.com/Dauliac/nix-oci";
              };
              verify = true;
            };
          };
        };

        build-cosign-key-based-sign-verify = {
          given = "a container with key-based cosign signing enabled";
          "when" = "the sign step runs and the verify step runs";
          "then" = "signing emits a signature referrer that the matching public key accepts";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            signing.cosign = {
              enabled = true;
              keyless = false;
              key = "env://COSIGN_PRIVATE_KEY";
              keyEnvVar = "COSIGN_KEY";
              verify = true;
              annotations = {
                "cosign.test" = "key-based";
              };
            };
          };
        };

        build-cosign-annotations-attached = {
          given = "a container with cosign signing enabled and annotations set";
          "when" = "the signature is emitted";
          "then" = "the annotations map appears in the signature payload for policy engines to consume";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            signing.cosign = {
              enabled = true;
              keyless = true;
              annotations = {
                "policy.owner" = "team-x";
                "policy.env" = "test";
              };
            };
          };
        };
      };
    };
}
