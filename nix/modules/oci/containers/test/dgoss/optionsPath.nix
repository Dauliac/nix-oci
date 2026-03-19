# Container test.dgoss.optionsPath option
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
        { name, ... }:
        {
          options.test.dgoss.optionsPath = lib.mkOption {
            type = lib.types.path;
            description = "Path to the dgoss configuration file.";
            default = cfg.oci.rootPath + name + "/test/dgoss.yaml";
            defaultText = lib.literalExpression ''config.oci.rootPath + name + "/test/dgoss.yaml"'';
          };
        };
    };
}
