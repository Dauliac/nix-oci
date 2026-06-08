# Container homeConfig.homeManagerFlake option
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.homeConfig.homeManagerFlake = mkOption {
            type = types.nullOr types.unspecified;
            description = ''
              The home-manager flake input. Required when homeConfig.enable is true.
              Provides home-manager.nixosModules.home-manager for the NixOS eval.
              Example: homeConfig.homeManagerFlake = inputs.home-manager;
            '';
            default = null;
          };
        };
    };
}
