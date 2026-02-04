# Container fromImage.os option
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.fromImage.os = lib.mkOption {
            type = lib.types.enum [ "linux" ];
            description = "The operating system for the image.";
            example = "linux";
            default = "linux";
          };
        };
    };
}
