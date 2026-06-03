# Container cve.vulnix.whitelist.path option
{
  lib,
  config,
  ...
}:
let
  cfg = config;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { name, ... }:
        {
          options.cve.vulnix.whitelist.path = lib.mkOption {
            type = lib.types.path;
            description = "Path to the vulnix whitelist TOML file.";
            default = cfg.oci.rootPath + name + "/cve/vulnix-whitelist.toml";
            defaultText = lib.literalExpression ''config.oci.rootPath + name + "/cve/vulnix-whitelist.toml"'';
          };
        };
    };
}
