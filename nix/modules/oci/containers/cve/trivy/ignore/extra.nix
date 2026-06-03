# Container cve.trivy.ignore.extra option
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.cve.trivy.ignore.extra = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Extra CVEs to ignore.";
            default = [ ];
          };
        };
    };
}
