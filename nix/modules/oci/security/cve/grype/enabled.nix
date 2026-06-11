{ lib, ... }:
{
  options.oci.cve.grype.enabled = lib.mkEnableOption "CVE scanning with Grype";
}
