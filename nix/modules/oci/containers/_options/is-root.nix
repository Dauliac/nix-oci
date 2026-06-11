# Shared: whether the container runs as root.
{
  lib,
  pkgs,
  ...
}:
{
  options.isRoot = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether the container process runs as root.";
    example = true;
  };

  config._tests.is-root = {
    level = "eval";
    default = {
      package = pkgs.hello;
    };
    override = {
      package = pkgs.hello;
      isRoot = true;
    };
  };
}
