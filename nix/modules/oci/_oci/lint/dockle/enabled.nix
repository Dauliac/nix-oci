{ lib, ... }:
{
  options.lint.dockle.enabled = lib.mkEnableOption "container image linting with Dockle";
}
