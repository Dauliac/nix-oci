{ lib, ... }:
{
  options.oci.cve.grype.config.enabled = lib.mkEnableOption "Grype configuration file generation";
}
