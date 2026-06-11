{
  config,
  lib,
  ...
}:
{
  options.oci.cve.grype.config.rootPath = lib.mkOption {
    type = lib.types.path;
    description = "Path where Grype configuration files will be stored.";
    default = config.oci.cve.configPath + "/grype/";
    defaultText = lib.literalExpression ''config.oci.cve.configPath + "/grype/"'';
  };
}
