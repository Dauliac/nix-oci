# Container sbom.syft.config.enabled option
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
        { ... }:
        {
          options.sbom.syft.config.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to use a syft config file.";
            default = cfg.oci.sbom.syft.config.enabled;
            defaultText = lib.literalExpression "config.oci.sbom.syft.config.enabled";
          };
        };
    };
}
