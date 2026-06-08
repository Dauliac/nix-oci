# Per-container: additional runtime dependencies.
{ lib, ... }:
{
  options.dependencies = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Additional packages included in the container root filesystem.";
  };
}
