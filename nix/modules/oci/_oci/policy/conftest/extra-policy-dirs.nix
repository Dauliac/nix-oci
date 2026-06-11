{ lib, ... }:
{
  options.policy.conftest.extraPolicyDirs = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    description = ''
      Additional directories containing Rego policy files.
      These are merged WITH the built-in policies.
    '';
    default = [ ];
    example = lib.literalExpression "[ ./my-policies ./team-policies ]";
  };
}
