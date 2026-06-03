# Container debug.entrypoint.enabled option
{ lib, ... }:
{
  config.perSystem =
    { config, ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.debug.entrypoint.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable debug entrypoint wrapper.";
            default = config.oci.debug.entrypoint.enabled;
            defaultText = lib.literalExpression "config.oci.debug.entrypoint.enabled";
          };
        };
    };
}
