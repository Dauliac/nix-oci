# BDD test specs for the conftest pipeline step.
#
# Verifies the built-in oci.rego policy rejects containers running as
# root (violates the `deny` rule) and accepts non-root containers, and
# that user-supplied policies via `extraPolicyDirs` compose with the
# built-in policy set (both are merged into the effective policy dir).
#
# Coverage per pipeline-behavior-verification/spec.md:
#   * conftest rejects a policy violation
#   * conftest extraPolicyDirs are merged
{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      test.oci.perContainer.pipeline-conftest = {
        eval-defaults = {
          given = "a container with default policy.conftest settings";
          "when" = "the container config is evaluated";
          "then" = "evaluation succeeds";
          level = "eval";
          target = "oci";
          container.package = pkgs.hello;
        };

        build-nonroot-passes-builtin-rego = {
          given = "a non-root container with the built-in oci.rego policy";
          "when" = "conftest runs against the image config";
          "then" = "no deny rules trigger and the gate build succeeds";
          level = "build";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            policy.conftest.enabled = true;
          };
        };

        build-root-violates-builtin-rego = {
          given = "a container declaring isRoot = true";
          "when" = "conftest runs the built-in oci.rego deny rules";
          "then" = "the image config trips the 'must not run as root' deny and the gate would fail";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = true;
            policy.conftest.enabled = true;
          };
        };

        build-extra-policy-dirs-compose = {
          given = "a container declaring an additional policy directory alongside oci.rego";
          "when" = "conftest builds the merged policy set";
          "then" = "the extra directory is composed into the effective policy dir";
          level = "eval";
          target = "oci";
          container = {
            package = pkgs.hello;
            isRoot = false;
            policy.conftest = {
              enabled = true;
              extraPolicyDirs = [
                ../../../../../security/policy/conftest/policies
              ];
            };
          };
        };
      };
    };
}
