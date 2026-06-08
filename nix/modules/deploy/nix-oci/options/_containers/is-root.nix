# Per-container: whether the container runs as root.
{ lib, ... }:
{
  options.isRoot = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Whether the container process runs as root.";
  };
}
