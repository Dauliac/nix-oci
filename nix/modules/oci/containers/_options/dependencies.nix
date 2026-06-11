# Shared: additional runtime dependencies.
{
  lib,
  pkgs,
  ...
}:
{
  options.dependencies = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Additional dependencies packages to include in the container.";
    example = lib.literalExpression "[ pkgs.bash pkgs.coreutils ]";
  };

  config._tests.dependencies = {
    level = "build";
    default = {
      package = pkgs.hello;
    };
    override = {
      package = pkgs.hello;
      dependencies = [
        pkgs.bash
        pkgs.coreutils
      ];
    };
  };
}
