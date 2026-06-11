# Container test.amicontained.enabled option
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
          options.test.amicontained.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable amicontained container introspection for this container.";
            default = cfg.oci.test.amicontained.enabled;
            defaultText = lib.literalExpression "config.oci.test.amicontained.enabled";
          };
          config._tests.test-amicontained-enabled = {
            level = "eval";
            default = {
              package = pkgs.hello;
            };
            override = {
              package = pkgs.hello;
              test.amicontained.enabled = true;
            };
          };
        };
    };
}
