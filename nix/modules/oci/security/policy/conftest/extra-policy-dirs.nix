{ lib, ... }:
{
  options.oci.policy.conftest.extraPolicyDirs = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    description = ''
      Additional directories containing Rego policy files.

      These are merged WITH the built-in policies (policyDir), not replacing
      them. Use this to layer organization-specific or project-specific
      policies on top of the nix-oci defaults.

      If an extra directory contains a file with the same name as a built-in
      policy, the extra directory's version takes precedence.
    '';
    default = [ ];
    example = lib.literalExpression "[ ./my-policies ./team-policies ]";
  };
}
