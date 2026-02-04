# Container cve.grype.config.path option
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
          options.cve.grype.config.path = lib.mkOption {
            type = lib.types.path;
            description = "Path to the grype config file.";
            default = cfg.oci.rootPath + containerName + "/cve/grype.yaml";
            defaultText = lib.literalExpression ''config.oci.rootPath + containerName + "/cve/grype.yaml"'';
          };
        };
    };
}
