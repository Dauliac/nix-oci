# Shared: main application package.
{
  lib,
  pkgs,
  ...
}:
{
  options.package = lib.mkOption {
    type = lib.types.nullOr lib.types.package;
    default = null;
    description = "The main package for the container.";
    example = lib.literalExpression "pkgs.hello";
  };
}
