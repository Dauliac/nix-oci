# Container isRoot option
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
          options.isRoot = mkOption {
            type = types.bool;
            description = "Whether the container is a root container.";
            default = false;
            example = true;
          };
        };
    };
}
