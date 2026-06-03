# Container cve.grype.config.enabled option
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
          options.cve.grype.config.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to use a grype config file.";
            default = cfg.oci.cve.grype.config.enabled;
          };
        };
    };
}
