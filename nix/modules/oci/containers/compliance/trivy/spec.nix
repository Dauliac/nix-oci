# Container compliance.trivy.spec option
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
          options.compliance.trivy.spec = lib.mkOption {
            type = lib.types.str;
            description = "The CIS compliance spec to check against.";
            default = cfg.oci.compliance.trivy.spec;
            defaultText = lib.literalExpression "config.oci.compliance.trivy.spec";
          };
        };
    };
}
