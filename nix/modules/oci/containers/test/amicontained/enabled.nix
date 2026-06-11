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
        { ... }:
        {
          options.test.amicontained.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable amicontained container introspection for this container.";
            default = cfg.oci.test.amicontained.enabled;
            defaultText = lib.literalExpression "config.oci.test.amicontained.enabled";
          };
        };
    };
}
