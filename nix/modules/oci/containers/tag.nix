# Container tag option
{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { config, ... }:
        {
          options.tag = mkOption {
            type = types.nullOr types.str;
            description = "Tag of the container.";
            default = cfg.lib.flake.oci.mkOCITag {
              inherit (config) package fromImage;
            };
            defaultText = lib.literalExpression "cfg.lib.flake.oci.mkOCITag { inherit package fromImage; }";
            example = "1.0.0";
          };
        };
    };
}
