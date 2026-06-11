{ lib, ... }:
{
  options.oci.container.performance.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable container performance tuning.";
  };
}
