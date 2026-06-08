# Container signing.cosign.keyless option
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
          options.signing.cosign.keyless = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to use keyless (OIDC) signing for this container.";
            default = cfg.oci.signing.cosign.keyless;
            defaultText = lib.literalExpression "config.oci.signing.cosign.keyless";
          };
        };
    };
}
