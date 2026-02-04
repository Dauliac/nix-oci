# Container entrypoint option
{
  lib,
  config,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config;
in
{
  config.perSystem =
    { ... }:
    {
      oci.perContainer =
        { config, ... }:
        {
          options.entrypoint = mkOption {
            type = types.listOf types.str;
            description = "The entrypoint command and arguments for the container. Will be automatically generated from the package if not specified.";
            default = cfg.lib.flake.oci.mkOCIEntrypoint { inherit (config) package; };
            defaultText = lib.literalExpression "cfg.lib.flake.oci.mkOCIEntrypoint { inherit package; }";
            example = [
              "/bin/sh"
              "-c"
              "echo hello"
            ];
          };
        };
    };
}
