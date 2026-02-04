# Container dependencies option
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
          options.dependencies = mkOption {
            type = types.listOf types.package;
            description = "Additional dependencies packages to include in the container.";
            default = [ ];
            example = lib.literalExpression "[ pkgs.bash pkgs.coreutils ]";
          };
        };
    };
}
