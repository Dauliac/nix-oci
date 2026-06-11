{ config, lib, ... }:
{
  options.sbom.path = lib.mkOption {
    type = lib.types.path;
    description = "Path where SBOM files will be stored.";
    default = config.rootPath;
    defaultText = lib.literalExpression "config.rootPath";
  };
}
