{ lib, ... }:
{
  options.cve.grype.enabled = lib.mkEnableOption "CVE scanning with Grype";
}
