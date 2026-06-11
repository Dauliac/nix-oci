{
  config,
  lib,
  ...
}:
{
  options.oci.cve.vulnix.whitelist.rootPath = lib.mkOption {
    type = lib.types.path;
    description = "Path where vulnix whitelist files will be stored.";
    default = config.oci.cve.configPath + "/vulnix/";
    defaultText = lib.literalExpression ''config.oci.cve.configPath + "/vulnix/"'';
  };
}
