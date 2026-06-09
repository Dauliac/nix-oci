# Container lint.dockle.ignore option
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
          options.lint.dockle.ignore = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "List of Dockle checkpoint IDs to ignore (e.g. `CIS-DI-0001`).";
            default = cfg.oci.lint.dockle.ignore;
            defaultText = lib.literalExpression "config.oci.lint.dockle.ignore";
            example = [
              "CIS-DI-0001"
              "DKL-DI-0006"
            ];
          };
        };
    };
}
