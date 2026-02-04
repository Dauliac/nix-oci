# Container cve.trivy.ignore.fileEnabled option
{ lib, ... }:
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.cve.trivy.ignore.fileEnabled = lib.mkEnableOption "Enable trivy ignore file";
        };
    };
}
