{
  lib,
  ...
}:
{
  options.oci.cve.trivy.enabled = lib.mkEnableOption "CVE scanning with Trivy";
}
