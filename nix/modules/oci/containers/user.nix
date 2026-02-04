# Container user option
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
          options.user = mkOption {
            type = types.nullOr types.str;
            description = "The user to run the container as. If null, will be automatically determined based on isRoot setting.";
            default = cfg.lib.flake.oci.mkOCIUser {
              inherit (config) name isRoot;
            };
            defaultText = lib.literalExpression "cfg.lib.flake.oci.mkOCIUser { inherit name isRoot; }";
          };
        };
    };
}
