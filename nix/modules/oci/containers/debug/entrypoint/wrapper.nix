# Container debug.entrypoint.wrapper option
{ lib, ... }:
{
  config.perSystem =
    { config, ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.debug.entrypoint.wrapper = lib.mkOption {
            type = lib.types.package;
            description = "Package containing the debug entrypoint wrapper.";
            default = config.oci.debug.entrypoint.wrapper;
            defaultText = lib.literalExpression "config.oci.debug.entrypoint.wrapper";
          };
        };
    };
}
