# Container sbom.rootPath option
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
          options.sbom.rootPath = lib.mkOption {
            type = lib.types.path;
            description = "The root path for the SBOM.";
            default = cfg.oci.rootPath + containerName + "/sbom/";
            defaultText = lib.literalExpression ''config.oci.rootPath + containerName + "/sbom/"'';
          };
        };
    };
}
