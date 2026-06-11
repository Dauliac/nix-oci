# Container policy.conftest.policyDir option
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
        { pkgs, ... }:
        {
          options.policy.conftest.policyDir = lib.mkOption {
            type = lib.types.path;
            description = ''
              Path to a directory containing Rego policy files for Conftest.

              Policies receive the OCI image config JSON as input and should
              define `deny` or `warn` rules.
            '';
            default = cfg.oci.policy.conftest.policyDir;
            defaultText = lib.literalExpression "config.oci.policy.conftest.policyDir";
          };
        };
    };
}
