# Container optimizeLayers option
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
          options.optimizeLayers = mkOption {
            type = types.bool;
            description = ''
              Split container contents into multiple layers for better registry caching.

              When enabled, dependencies are placed in a separate layer from the
              application package, and both are further split by popularity
              (inspired by Nixery/grahamc's layering strategy). This means:
              - Stable dependencies produce cached layers shared across rebuilds
              - Only the thin application layer is pushed on code changes
            '';
            default = false;
            example = true;
          };
        };
    };
}
