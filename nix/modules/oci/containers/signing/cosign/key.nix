# Container signing.cosign.key option
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
          options.signing.cosign.key = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            description = "Path or KMS URI for cosign key for this container. Only used when keyless is false.";
            default = cfg.oci.signing.cosign.key;
            defaultText = lib.literalExpression "config.oci.signing.cosign.key";
          };
        };
    };
}
