{ lib, ... }:
{
  options.enableDevShell = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable the flake development shell.";
    default = false;
  };
}
