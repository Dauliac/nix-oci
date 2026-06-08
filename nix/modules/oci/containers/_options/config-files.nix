# Shared: configuration file derivations.
{ lib, ... }:
{
  options.configFiles = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Configuration file derivations to include in the container root.";
  };
}
