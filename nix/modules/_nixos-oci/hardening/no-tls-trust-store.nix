{ lib, ... }:
{
  options.oci.container.hardening.noTlsTrustStore = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Remove TLS trust store.";
  };
}
