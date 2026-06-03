# Container tags option
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
          options.tags = mkOption {
            type = types.listOf types.str;
            description = "List of tags for the container. All tags will be pushed to the registry. The first tag is used for the local build.";
            default = [ config.tag ];
            defaultText = lib.literalExpression "[ tag ]";
            example = [
              "1.0.0"
              "latest"
              "stable"
            ];
          };
        };
    };
}
