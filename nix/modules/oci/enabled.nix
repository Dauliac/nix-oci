# OCI enabled option
{ lib, ... }:
{
  options.oci.enabled = lib.mkEnableOption "Enable the OCI module.";
}
