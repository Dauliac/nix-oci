# Container fromImage.imageTag option
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.fromImage.imageTag = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "The tag/version of the image.";
            example = "3.21.2";
            default = null;
          };
        };
    };
}
