# Container installNix option
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.installNix = mkOption {
            type = types.bool;
            description = "Whether to install nix in the container.";
            default = false;
            example = true;
          };
        };
    };
}
