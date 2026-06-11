{ lib, ... }:
{
  options.cve.trivy.ignore.extra = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = "Additional CVE identifiers to ignore globally in Trivy scans.";
    default = [ ];
  };
}
