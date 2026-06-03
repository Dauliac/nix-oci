# Container cve.trivy.enabled option
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
          options.cve.trivy.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable Trivy CVE scanning.";
            default = cfg.oci.cve.trivy.enabled;
          };
        };
    };
}
