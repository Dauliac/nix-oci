# Container tag option (flake-parts wrapper with computed default)
{ config, ... }:
let
  cfg = config;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        {
          config,
          lib,
          ...
        }:
        {
          imports = [ ./_options/tag.nix ];
          config.tag = lib.mkDefault (cfg.lib.flake.oci.mkOCITag { inherit (config) package fromImage; });
        };
    };
}
