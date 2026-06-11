{ lib, ... }:
{
  options.credentialsLeak.trivy.enabled = lib.mkEnableOption "credentials leak detection with Trivy";
}
