{ lib, ... }:
{
  options.test.deepce.enabled = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable DEEPCE container escape detection globally for all containers.";
    default = false;
  };
}
