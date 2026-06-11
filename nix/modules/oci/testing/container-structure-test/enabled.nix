{ lib, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options.oci.test.containerStructureTest.enabled = mkOption {
    type = types.bool;
    description = "Whether to enable container-structure-test globally for all containers.";
    default = false;
  };
}
