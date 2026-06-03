# Container multiArch.tempTagPrefix option
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.multiArch.tempTagPrefix = lib.mkOption {
            type = lib.types.str;
            description = "Prefix for temporary architecture-specific tags.";
            default = "tmp";
            example = "arch";
          };
        };
    };
}
