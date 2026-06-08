# Deploy-specific default overrides for shared options.
#
# Deploy containers default to isRoot=true and optimizeLayers=true
# (different from flake-parts CI defaults).
{ lib, ... }:
{
  config = {
    isRoot = lib.mkDefault true;
    optimizeLayers = lib.mkDefault true;
  };
}
