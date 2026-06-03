# Container cve.grype.enabled option
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
          options.cve.grype.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to run grype.";
            default = cfg.oci.cve.grype.enabled;
          };
        };
    };
}
