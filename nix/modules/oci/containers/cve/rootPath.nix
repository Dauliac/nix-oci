# Container cve.rootPath option
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
          options.cve.rootPath = lib.mkOption {
            type = lib.types.path;
            description = "The root path for CVE configuration files.";
            default = cfg.oci.rootPath + name + "/cve/";
            defaultText = lib.literalExpression ''config.oci.rootPath + name + "/cve/"'';
          };
        };
    };
}
