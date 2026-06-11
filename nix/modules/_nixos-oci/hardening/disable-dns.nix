{ lib, ... }:
{
  options.oci.container.hardening.disableDns = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Disable DNS resolution.";
  };
}
