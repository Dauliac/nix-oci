{ lib, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options.oci.test.dgoss.enabled = mkOption {
    type = types.bool;
    description = "Whether to enable dgoss testing globally for all containers.";
    default = false;
  };
}
