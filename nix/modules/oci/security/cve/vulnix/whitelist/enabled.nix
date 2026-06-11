{
  lib,
  ...
}:
{
  options.oci.cve.vulnix.whitelist.enabled = lib.mkEnableOption "vulnix whitelist file";
}
