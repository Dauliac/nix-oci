# Container lint.dockle.exitLevel option
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
          options.lint.dockle.exitLevel = lib.mkOption {
            type = lib.types.enum [
              "info"
              "warn"
              "fatal"
            ];
            description = "Minimum severity level that causes a non-zero exit code.";
            default = cfg.oci.lint.dockle.exitLevel;
            defaultText = lib.literalExpression "config.oci.lint.dockle.exitLevel";
          };
        };
    };
}
