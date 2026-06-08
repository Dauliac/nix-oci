# Container compliance.trivy.report option
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
          options.compliance.trivy.report = lib.mkOption {
            type = lib.types.enum [
              "all"
              "summary"
            ];
            description = "Compliance report format: `all` for detailed results or `summary` for a condensed overview.";
            default = cfg.oci.compliance.trivy.report;
            defaultText = lib.literalExpression "config.oci.compliance.trivy.report";
          };
        };
    };
}
