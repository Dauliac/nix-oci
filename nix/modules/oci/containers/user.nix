# Container user option (flake-parts wrapper with computed default)
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
          imports = [ ./_options/user.nix ];
          config.user = lib.mkDefault (
            cfg.lib.flake.oci.mkOCIUser { inherit (config) name isRoot; }
          );
        };
    };
}
