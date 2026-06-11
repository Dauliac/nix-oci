{ lib, ... }:
{
  options.sbom.syft.config.enabled = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable Syft configuration file generation.";
    default = false;
  };
}
