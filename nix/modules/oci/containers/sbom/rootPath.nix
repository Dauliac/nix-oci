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
        { name, ... }:
        {
          options.sbom.rootPath = lib.mkOption {
            type = lib.types.path;
            description = "The root path for the SBOM.";
            default = cfg.oci.rootPath + name + "/sbom/";
            defaultText = lib.literalExpression ''config.oci.rootPath + name + "/sbom/"'';
          };
        };
    };
}
