# Container cve.trivy.ignore.path option
{
  lib,
  config,
  ...
}:
let
  cfg = config;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { containerName, ... }:
        {
          options.cve.trivy.ignore.path = lib.mkOption {
            type = lib.types.nullOr lib.types.path;
            description = "Path to the trivy ignore file.";
            default = cfg.oci.rootPath + containerName + "/cve/trivy.ignore";
            defaultText = lib.literalExpression ''config.oci.rootPath + containerName + "/cve/trivy.ignore"'';
          };
        };
    };
}
