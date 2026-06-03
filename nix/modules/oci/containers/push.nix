# Container push option
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
          options.push = mkOption {
            type = types.bool;
            description = "Whether to push the container to the OCI registry.";
            default = false;
            example = true;
          };
        };
    };
}
