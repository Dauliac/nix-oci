# Container registry option
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
          options.registry = mkOption {
            type = types.nullOr types.str;
            description = ''
              Container registry prefix (e.g., "ghcr.io/my-org" or "my-registry.io/project").
              If set, the full container name will be "registry/name".
              If null or empty string, no registry prefix will be added.
            '';
            default = null;
            example = "ghcr.io/my-org";
          };
        };
    };
}
