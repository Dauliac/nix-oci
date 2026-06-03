# Container rootPath option
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
        { name, ... }:
        {
          options.rootPath = mkOption {
            type = types.path;
            description = "The root path for the container.";
            default = cfg.oci.rootPath + name + "/";
            defaultText = lib.literalExpression ''config.oci.rootPath + name + "/"'';
          };
        };
    };
}
