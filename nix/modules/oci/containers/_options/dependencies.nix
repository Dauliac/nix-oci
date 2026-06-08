# Shared: additional runtime dependencies.
{ lib, ... }:
{
  options.dependencies = lib.mkOption {
    type = lib.types.listOf lib.types.package;
    default = [ ];
    description = "Additional dependencies packages to include in the container.";
    example = lib.literalExpression "[ pkgs.bash pkgs.coreutils ]";
  };
}
