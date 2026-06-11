{ lib, ... }:
{
  options.oci.container.hardening.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable container security hardening.";
  };
}
