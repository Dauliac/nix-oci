# Per-container: main application package.
{ lib, ... }:
{
  options.package = lib.mkOption {
    type = lib.types.package;
    description = "The main application package to containerize.";
  };
}
