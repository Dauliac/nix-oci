# Container test.deepce.enabled option
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
        { pkgs, ... }:
        {
          options.test.deepce.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable DEEPCE container escape detection for this container.";
            default = cfg.oci.test.deepce.enabled;
            defaultText = lib.literalExpression "config.oci.test.deepce.enabled";
          };
          config._tests.test-deepce-enabled = {
            level = "eval";
            default = {
              package = pkgs.hello;
            };
            override = {
              package = pkgs.hello;
              test.deepce.enabled = true;
            };
          };
        };
    };
}
