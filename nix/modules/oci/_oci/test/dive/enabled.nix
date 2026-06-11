{ lib, ... }:
{
  options.test.dive.enabled = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable Dive analysis globally for all containers.";
    default = false;
  };
}
