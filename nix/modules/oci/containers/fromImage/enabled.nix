# Container fromImage.enabled option
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { config, ... }:
        {
          options.fromImage.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to use a base image for this container. Defaults to true when imageName is set.";
            default = config.fromImage.imageName != null;
            defaultText = lib.literalExpression "config.fromImage.imageName != null";
          };
        };
    };
}
