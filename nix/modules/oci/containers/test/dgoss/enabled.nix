# Container test.dgoss.enabled option
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
          options.test.dgoss.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable dgoss testing for the container.";
            default = cfg.oci.test.dgoss.enabled;
            defaultText = lib.literalExpression "cfg.oci.test.dgoss.enabled";
          };
        };
    };
}
