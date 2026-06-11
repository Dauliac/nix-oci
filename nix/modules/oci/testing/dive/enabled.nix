{ lib, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options.oci.test.dive.enabled = mkOption {
    type = types.bool;
    description = "Whether to enable Dive analysis globally for all containers.";
    default = false;
  };
}
