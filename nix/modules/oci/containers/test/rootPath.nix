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
        { name, ... }:
        {
          options.test.rootPath = lib.mkOption {
            type = lib.types.path;
            description = "The root path for the test.";
            default = cfg.oci.rootPath + name + "/test/";
            defaultText = lib.literalExpression ''config.oci.rootPath + name + "/test/"'';
          };
        };
    };
}
