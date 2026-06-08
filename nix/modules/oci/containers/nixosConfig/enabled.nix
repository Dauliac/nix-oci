# Container nixosConfig.enable option
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.nixosConfig.enable = lib.mkEnableOption "NixOS module-based configuration for this container";
        };
    };
}
