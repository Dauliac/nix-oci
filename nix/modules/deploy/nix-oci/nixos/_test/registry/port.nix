{ lib, ... }:
{
  options.testing.registry.port = lib.mkOption {
    type = lib.types.port;
    default = 5000;
    description = "Port for the localhost test registry.";
  };
}
