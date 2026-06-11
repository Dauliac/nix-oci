{ config, lib, ... }:
{
  options.sbom.syft.config.rootPath = lib.mkOption {
    type = lib.types.path;
    description = "Path where Syft configuration files will be stored.";
    default = config.sbom.path;
    defaultText = lib.literalExpression "config.sbom.path";
  };
}
