{ lib, ... }:
{
  options.cve.vulnix.enabled = lib.mkEnableOption "CVE scanning with vulnix";
}
