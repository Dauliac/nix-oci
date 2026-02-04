# Container credentialsLeak.trivy.enabled option
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
          options.credentialsLeak.trivy.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable Trivy credentials leak scanning.";
            default = cfg.oci.cve.trivy.enabled;
            defaultText = lib.literalExpression "config.oci.cve.trivy.enabled";
          };
        };
    };
}
