# Container test.dive.enabled option
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
          options.test.dive.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable Dive analysis for container image layers and efficiency.";
            default = cfg.oci.test.dive.enabled;
            defaultText = lib.literalExpression "cfg.oci.test.dive.enabled";
            example = true;
          };
        };
    };
}
