# Per-container: layer optimization for local deploy.
{ lib, ... }:
{
  options.optimizeLayers = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Split container into multiple layers for better local caching.
      Defaults to true for deploy (no push cost, shared layers save disk).
    '';
  };
}
