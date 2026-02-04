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
        { containerName, ... }:
        {
          options.cve.rootPath = lib.mkOption {
            type = lib.types.path;
            description = "The root path for CVE configuration files.";
            default = cfg.oci.rootPath + containerName + "/cve/";
            defaultText = lib.literalExpression ''config.oci.rootPath + containerName + "/cve/"'';
          };
        };
    };
}
