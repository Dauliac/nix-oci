{
  config,
  lib,
  ...
}:
{
  options.credentialsLeak.configPath = lib.mkOption {
    type = lib.types.path;
    default = config.rootPath + "/credentials-leak/";
    defaultText = lib.literalExpression ''config.rootPath + "/credentials-leak/"'';
    description = "Path where global credentials leak check configuration files will be stored.";
  };
}
