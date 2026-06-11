{ lib, ... }:
{
  options.sbom.syft.enabled = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable SBOM generation with Syft.";
    default = false;
  };
}
