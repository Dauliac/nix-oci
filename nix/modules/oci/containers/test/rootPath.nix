# Container test.rootPath option
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
          options.test.rootPath = lib.mkOption {
            type = lib.types.path;
            description = "The root path for the test.";
            default = cfg.oci.rootPath + containerName + "/test/";
            defaultText = lib.literalExpression ''config.oci.rootPath + containerName + "/test/"'';
          };
        };
    };
}
