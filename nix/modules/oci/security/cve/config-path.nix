{
  config,
  lib,
  ...
}:
{
  options.oci.cve.configPath = lib.mkOption {
    type = lib.types.path;
    default = config.oci.rootPath;
    defaultText = lib.literalExpression "cfg.oci.rootPath";
    description = "Path where CVE scanner configuration files will be stored.";
  };
}
