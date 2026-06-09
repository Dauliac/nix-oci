# Debug-only home-manager flake input
#
# Defaults to the parent homeConfig.homeManagerFlake so debug inherits
# the prod flake reference. Set explicitly when debug needs HM but prod doesn't.
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { config, ... }:
        {
          options.debug.homeConfig.homeManagerFlake = lib.mkOption {
            type = lib.types.nullOr lib.types.unspecified;
            description = ''
              The home-manager flake input for the debug variant.
              Defaults to the production homeConfig.homeManagerFlake.
              When set, enables home-manager for the debug variant.
              Set to null to disable debug home-manager even when production uses it.
            '';
            default = config.homeConfig.homeManagerFlake;
            defaultText = lib.literalExpression "config.homeConfig.homeManagerFlake";
          };
        };
    };
}
