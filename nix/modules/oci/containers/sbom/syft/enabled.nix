# Container sbom.syft.enabled option
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
          options.sbom.syft.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable Syft SBOM generation.";
            default = cfg.oci.sbom.syft.enabled;
            defaultText = lib.literalExpression "config.oci.sbom.syft.enabled";
          };
        };
    };
}
