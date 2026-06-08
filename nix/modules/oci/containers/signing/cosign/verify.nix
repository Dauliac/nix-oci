# Container signing.cosign.verify option
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
          options.signing.cosign.verify = lib.mkOption {
            type = lib.types.bool;
            description = "Whether to verify the signature immediately after signing.";
            default = cfg.oci.signing.cosign.verify;
            defaultText = lib.literalExpression "config.oci.signing.cosign.verify";
          };
        };
    };
}
