# Container name option (flake-parts wrapper with computed default)
{ config, ... }:
let
  cfg = config;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { config, lib, ... }:
        {
          imports = [ ./_options/name.nix ];
          config.name = lib.mkDefault (
            cfg.lib.flake.oci.mkOCIName { inherit (config) package fromImage; }
          );
        };
    };
}
