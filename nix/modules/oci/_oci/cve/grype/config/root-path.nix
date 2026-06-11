{ config, lib, ... }:
{
  options.cve.grype.config.rootPath = lib.mkOption {
    type = lib.types.path;
    description = "Path where Grype configuration files will be stored.";
    default = config.cve.configPath + "/grype/";
    defaultText = lib.literalExpression ''config.cve.configPath + "/grype/"'';
  };
}
