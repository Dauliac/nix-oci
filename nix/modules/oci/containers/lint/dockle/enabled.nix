# Container lint.dockle.enabled option
{
  lib,
  config,
  ...
}:
let
  cfg = config;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { ... }:
        {
          options.lint.dockle.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable container image linting with Dockle.";
            default = cfg.oci.lint.dockle.enabled;
            defaultText = lib.literalExpression "config.oci.lint.dockle.enabled";
          };
        };
    };
}
