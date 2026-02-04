# Container package option
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
          options.package = mkOption {
            type = types.nullOr types.package;
            description = "The main package for the container";
            default = null;
            example = lib.literalExpression "pkgs.hello";
          };
        };
    };
}
