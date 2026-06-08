# Container compliance.trivy.enabled option
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
          options.compliance.trivy.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable CIS compliance checking with Trivy.";
            default = cfg.oci.compliance.trivy.enabled;
            defaultText = lib.literalExpression "config.oci.compliance.trivy.enabled";
          };
        };
    };
}
