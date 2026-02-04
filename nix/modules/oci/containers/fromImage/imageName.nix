# Container fromImage.imageName option
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.fromImage.imageName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "The name of the base image.";
            example = "library/alpine";
            default = null;
          };
        };
    };
}
