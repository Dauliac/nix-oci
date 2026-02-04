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
        { containerName, ... }:
        {
          options.test.dgoss.optionsPath = lib.mkOption {
            type = lib.types.path;
            description = "Path to the dgoss configuration file.";
            default = cfg.oci.rootPath + containerName + "/test/dgoss.yaml";
            defaultText = lib.literalExpression ''config.oci.rootPath + containerName + "/test/dgoss.yaml"'';
          };
        };
    };
}
