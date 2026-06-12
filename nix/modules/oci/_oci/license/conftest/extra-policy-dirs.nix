{ lib, ... }:
{
  options.license.conftest.extraPolicyDirs = lib.mkOption {
    type = lib.types.listOf lib.types.path;
    description = ''
      Additional directories containing Rego policy files for license checking.
      These are merged WITH the built-in license policies.
    '';
    default = [ ];
    example = lib.literalExpression "[ ./my-license-policies ]";
  };
}
