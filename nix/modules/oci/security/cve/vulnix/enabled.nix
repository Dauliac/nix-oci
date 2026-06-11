{
  lib,
  ...
}:
{
  options.oci.cve.vulnix.enabled = lib.mkEnableOption "CVE scanning with vulnix";
}
