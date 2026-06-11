{ lib, ... }:
{
  options.cve.trivy.ignore.fileEnabled = lib.mkEnableOption "Trivy CVE ignore file generation";
}
