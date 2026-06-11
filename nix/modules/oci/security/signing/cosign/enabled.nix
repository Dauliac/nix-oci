{
  lib,
  ...
}:
{
  options.oci.signing.cosign.enabled = lib.mkEnableOption "OCI image signing with cosign";
}
