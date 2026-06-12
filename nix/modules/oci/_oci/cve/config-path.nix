{
  config,
  lib,
  ...
}:
{
  options.cve.configPath = lib.mkOption {
    type = lib.types.path;
    default = config.rootPath;
    defaultText = lib.literalExpression "config.rootPath";
    description = "Path where CVE scanner configuration files will be stored.";
  };
}
