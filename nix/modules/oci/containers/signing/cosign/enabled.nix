# Container signing.cosign.enabled option
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
          options.signing.cosign.enabled = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to enable cosign image signing for this container.";
            default = cfg.oci.signing.cosign.enabled;
            defaultText = lib.literalExpression "config.oci.signing.cosign.enabled";
          };
        };
    };
}
