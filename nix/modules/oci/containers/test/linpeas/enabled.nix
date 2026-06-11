# Container test.linpeas.enabled option
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
          options.test.linpeas.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable linPEAS privilege escalation auditing for this container.";
            default = cfg.oci.test.linpeas.enabled;
            defaultText = lib.literalExpression "config.oci.test.linpeas.enabled";
          };
        };
    };
}
