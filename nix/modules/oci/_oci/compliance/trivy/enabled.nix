{ lib, ... }:
{
  options.compliance.trivy.enabled = lib.mkEnableOption "CIS compliance checking with Trivy";
}
