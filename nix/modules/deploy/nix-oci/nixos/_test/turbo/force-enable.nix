{ lib, ... }:
{
  options.testing.turbo.forceEnable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Force nix2container-turbo for all test containers.";
  };
}
