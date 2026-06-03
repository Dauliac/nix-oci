# Container cve.vulnix.whitelist.enabled option
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
          options.cve.vulnix.whitelist.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to use a vulnix whitelist file.";
            default = cfg.oci.cve.vulnix.whitelist.enabled;
          };
        };
    };
}
