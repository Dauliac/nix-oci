# Container test.cdk.enabled option
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
          options.test.cdk.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable CDK container security auditing for this container.";
            default = cfg.oci.test.cdk.enabled;
            defaultText = lib.literalExpression "config.oci.test.cdk.enabled";
          };
        };
    };
}
