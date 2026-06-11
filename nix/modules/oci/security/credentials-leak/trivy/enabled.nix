{
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption;
in
{
  options.oci.credentialsLeak.trivy.enabled = mkEnableOption "credentials leak detection with Trivy";
}
