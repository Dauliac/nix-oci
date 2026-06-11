{ lib, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options.oci.sbom.syft.config.enabled = mkOption {
    type = types.bool;
    description = "Whether to enable Syft configuration file generation.";
    default = false;
  };
}
