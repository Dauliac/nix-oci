# Container entrypoint option (flake-parts wrapper with computed default)
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
          imports = [ ./_options/entrypoint.nix ];
          config.entrypoint = lib.mkDefault (
            cfg.lib.flake.oci.mkOCIEntrypoint { inherit (config) package; }
          );
        };
    };
}
