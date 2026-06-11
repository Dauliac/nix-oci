{ lib, ... }:
{
  options.oci.policy.conftest.policyDir = lib.mkOption {
    type = lib.types.path;
    description = ''
      Path to a directory containing Rego policy files for Conftest.

      Policies receive the OCI image config JSON as input and should
      define `deny` or `warn` rules. nix-oci ships built-in policies
      that check for common security issues (root user, leaked secrets
      in env vars, missing labels).
    '';
    default = ./policies;
    defaultText = lib.literalExpression "built-in nix-oci OCI policies";
  };
}
