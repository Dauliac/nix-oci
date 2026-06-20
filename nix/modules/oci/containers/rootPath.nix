# Per-container rootPath computed default.
# The option is declared in _oci/rootPath.nix (shared).
# This module provides the per-container computed default
# using mkDefault, appending the container name to the perSystem base path.
{
  lib,
  flake-parts-lib,
  ...
}:
{
  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { config, ... }:
    {
      config.oci.perContainer =
        {
          name,
          lib,
          ...
        }:
        {
          config.rootPath = lib.mkDefault (config.oci.rootPath + name + "/");
        };
    }
  );
}
