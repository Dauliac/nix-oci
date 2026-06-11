{ lib, ... }:
{
  options.cve.vulnix.whitelist.enabled = lib.mkEnableOption "vulnix whitelist file";
}
