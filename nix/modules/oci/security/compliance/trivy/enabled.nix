{ lib, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  options.oci.compliance.trivy.enabled = mkEnableOption "CIS compliance checking with Trivy";
}
