{ config, lib, ... }:
{
  options.cve.trivy.ignore.rootPath = lib.mkOption {
    type = lib.types.path;
    description = "Path where Trivy CVE ignore files will be stored.";
    default = config.cve.configPath;
    defaultText = lib.literalExpression "config.cve.configPath";
  };
}
