# Debug container labels option
#
# Labels for the debug variant. Falls back to the production labels
# when not set.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { config, ... }:
        {
          options.debug.labels = mkOption {
            type = types.attrsOf types.str;
            default = config.labels;
            defaultText = lib.literalExpression "config.labels";
            description = ''
              OCI image labels for the debug variant.
              Defaults to the production container's labels.
            '';
          };
        };
    };
}
