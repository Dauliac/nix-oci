{ lib, ... }:
{
  options.testing.registry.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Enable localhost Docker registry for policy tool testing.";
  };
}
