{ lib, ... }:
{
  options.test.containerStructureTest.enabled = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable container-structure-test globally for all containers.";
    default = false;
  };
}
