{ lib, ... }:
let
  inherit (lib)
    mkOption
    types
    ;
in
{
  options.oci.sbom.syft.enabled = mkOption {
    type = types.bool;
    description = "Whether to enable SBOM generation with Syft.";
    default = false;
  };
}
