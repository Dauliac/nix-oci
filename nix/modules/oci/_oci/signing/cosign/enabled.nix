{ lib, ... }:
{
  options.signing.cosign.enabled = lib.mkEnableOption "OCI image signing with cosign";
}
