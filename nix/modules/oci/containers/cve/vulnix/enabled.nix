# Container cve.vulnix.enabled option
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
          options.cve.vulnix.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to run vulnix CVE scanning.";
            default = cfg.oci.cve.vulnix.enabled;
          };
        };
    };
}
