{
  config,
  lib,
  ...
}:
{
  options.oci.cve.trivy.ignore.rootPath = lib.mkOption {
    type = lib.types.path;
    description = "Path where Trivy CVE ignore files will be stored.";
    default = config.oci.cve.configPath;
    defaultText = lib.literalExpression "cfg.oci.cve.configPath";
  };
}
