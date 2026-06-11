{ lib, ... }:
{
  options.cve.trivy.enabled = lib.mkEnableOption "CVE scanning with Trivy";
}
