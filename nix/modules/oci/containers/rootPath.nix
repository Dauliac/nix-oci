# Per-container rootPath computed default.
# The option is declared in _oci/rootPath.nix (shared).
# This module only provides the per-container computed default
# using mkDefault (priority 1000) to override the bridge (1500).
{
  lib,
  config,
  ...
}:
let
  cfg = config;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { name, lib, ... }:
        {
          config.rootPath = lib.mkDefault (cfg.oci.rootPath + name + "/");
        };
    };
}
