# Container debug.enabled option
{ lib, ... }:
{
  config.perSystem =
    { config, ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.debug.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable debug build with additional debugging tools.";
            default = config.oci.debug.enabled;
            defaultText = lib.literalExpression "config.oci.debug.enabled";
          };
        };
    };
}
