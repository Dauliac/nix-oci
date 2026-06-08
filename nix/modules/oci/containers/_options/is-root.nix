# Shared: whether the container runs as root.
{ lib, ... }:
{
  options.isRoot = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether the container process runs as root.";
    example = true;
  };
}
