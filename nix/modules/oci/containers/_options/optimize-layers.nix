# Shared: layer optimization.
{ lib, ... }:
{
  options.optimizeLayers = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Split container contents into multiple layers for better caching.";
    example = true;
  };
}
