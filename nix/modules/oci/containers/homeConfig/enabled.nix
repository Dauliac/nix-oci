# Container homeConfig.enable option
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.homeConfig.enable = lib.mkEnableOption "home-manager dotfiles for the container user";
        };
    };
}
