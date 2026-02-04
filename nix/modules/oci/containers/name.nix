# Container name option
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
          options.name = mkOption {
            type = types.nullOr types.str;
            description = "Name of the container. If null, the name will be automatically generated from the package or base image.";
            default = cfg.lib.flake.oci.mkOCIName {
              inherit (config) package fromImage;
            };
            defaultText = lib.literalExpression "cfg.lib.flake.oci.mkOCIName { inherit package fromImage; }";
            example = "my-app";
          };
        };
    };
}
