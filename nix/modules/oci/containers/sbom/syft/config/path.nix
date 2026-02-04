# Container sbom.syft.config.path option
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
          options.sbom.syft.config.path = lib.mkOption {
            type = lib.types.path;
            description = "Path to the syft config file.";
            default = cfg.oci.rootPath + containerName + "/sbom/syft.yaml";
            defaultText = lib.literalExpression ''config.oci.rootPath + containerName + "/sbom/syft.yaml"'';
          };
        };
    };
}
