{ lib, ... }:
{
  options.test.dgoss.enabled = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable dgoss testing globally for all containers.";
    default = false;
  };
}
