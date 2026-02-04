# Container multiArch.enabled option
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.multiArch.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Enable multi-arch manifest creation for this container.";
            default = false;
            example = true;
          };
        };
    };
}
