# Container debug.packages option
{ lib, ... }:
{
  config.perSystem =
    { config, ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.debug.packages = lib.mkOption {
            type = lib.types.listOf lib.types.package;
            description = "List of additional packages to include in debug builds.";
            default = config.oci.debug.packages;
            defaultText = lib.literalExpression "config.oci.debug.packages";
          };
        };
    };
}
