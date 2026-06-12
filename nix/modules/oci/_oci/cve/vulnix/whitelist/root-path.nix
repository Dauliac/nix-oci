{
  config,
  lib,
  ...
}:
{
  options.cve.vulnix.whitelist.rootPath = lib.mkOption {
    type = lib.types.path;
    description = "Path where vulnix whitelist files will be stored.";
    default = config.cve.configPath + "/vulnix/";
    defaultText = lib.literalExpression ''config.cve.configPath + "/vulnix/"'';
  };
}
