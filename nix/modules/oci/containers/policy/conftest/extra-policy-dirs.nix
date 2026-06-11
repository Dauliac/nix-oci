# Container policy.conftest.extraPolicyDirs option
{
  lib,
  config,
  ...
}:
let
  cfg = config;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.policy.conftest.extraPolicyDirs = lib.mkOption {
            type = lib.types.listOf lib.types.path;
            description = ''
              Additional directories containing Rego policy files.
              Merged with the base policyDir rather than replacing it.
            '';
            default = cfg.oci.policy.conftest.extraPolicyDirs;
            defaultText = lib.literalExpression "config.oci.policy.conftest.extraPolicyDirs";
          };
        };
    };
}
